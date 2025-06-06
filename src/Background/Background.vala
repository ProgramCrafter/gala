/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2014 Tom Beckmann
 *                         2025 elementary, Inc. (https://elementary.io)
 */

public class Gala.Background : Object {
    private const double ANIMATION_OPACITY_STEP_INCREMENT = 4.0;
    private const double ANIMATION_MIN_WAKEUP_INTERVAL = 1.0;

    public signal void changed ();
    public signal void loaded ();

    public Meta.Display display { get; construct; }
    public int monitor_index { get; construct; }
    public BackgroundSource background_source { get; construct; }
    public bool is_loaded { get; private set; default = false; }
    public GDesktop.BackgroundStyle style { get; construct; }
    public string? filename { get; construct; }
    public Meta.Background background { get; private set; }

    private Animation? animation = null;
    private Gee.HashMap<string,ulong> file_watches;
    private Cancellable cancellable;
    private uint update_animation_timeout_id = 0;

    private Gnome.WallClock clock;
    private ulong clock_timezone_handler = 0;

    public Background (Meta.Display display, int monitor_index, string? filename,
            BackgroundSource background_source, GDesktop.BackgroundStyle style) {
        Object (display: display,
                monitor_index: monitor_index,
                background_source: background_source,
                style: style,
                filename: filename);
    }

    construct {
        background = new Meta.Background (display);
        background.set_data<unowned Background> ("delegate", this);

        file_watches = new Gee.HashMap<string,ulong> ();
        cancellable = new Cancellable ();

        background_source.changed.connect (settings_changed);

        clock = new Gnome.WallClock ();
        clock_timezone_handler = clock.notify["timezone"].connect (() => {
            if (animation != null) {
                load_animation.begin (animation.filename);
            }
        });

        load ();
    }

    public void destroy () {
        cancellable.cancel ();
        remove_animation_timeout ();

        var cache = BackgroundCache.get_default ();

        foreach (var watch in file_watches.values) {
            cache.disconnect (watch);
        }

        background_source.changed.disconnect (settings_changed);

        if (clock_timezone_handler != 0) {
            clock.disconnect (clock_timezone_handler);
        }
    }

    public void update_resolution () {
        if (animation != null) {
            remove_animation_timeout ();
            update_animation ();
        }
    }

    private void set_loaded () {
        if (is_loaded)
            return;

        is_loaded = true;

        Idle.add (() => {
            loaded ();
            return Source.REMOVE;
        });
    }

    private void load_pattern () {
        string color_string;
        var settings = background_source.gnome_background_settings;

        color_string = settings.get_string ("primary-color");
#if HAS_MUTTER47
        var color = Cogl.Color.from_string (color_string);
#else
        var color = Clutter.Color.from_string (color_string);
#endif
        if (color == null) {
#if HAS_MUTTER47
            color = Cogl.Color.from_string ("black");
#else
            color = Clutter.Color.from_string ("black");
#endif
        }

        var shading_type = settings.get_enum ("color-shading-type");

        if (shading_type == GDesktop.BackgroundShading.SOLID) {
            background.set_color (color);
        } else {
            color_string = settings.get_string ("secondary-color");
#if HAS_MUTTER47
            var second_color = Cogl.Color.from_string (color_string);
#else
            var second_color = Clutter.Color.from_string (color_string);
#endif
            if (second_color == null) {
#if HAS_MUTTER47
                second_color = Cogl.Color.from_string ("black");
#else
                second_color = Clutter.Color.from_string ("black");
#endif
            }

            background.set_gradient ((GDesktop.BackgroundShading) shading_type, color, second_color);
        }
    }

    private void watch_file (string filename) {
        if (file_watches.has_key (filename))
            return;

        var cache = BackgroundCache.get_default ();

        cache.monitor_file (filename);

        file_watches[filename] = cache.file_changed.connect ((changed_file) => {
            if (changed_file == filename) {
                var image_cache = Meta.BackgroundImageCache.get_default ();
                image_cache.purge (File.new_for_path (changed_file));
                changed ();
            }
        });
    }

    private void remove_animation_timeout () {
        if (update_animation_timeout_id != 0) {
            Source.remove (update_animation_timeout_id);
            update_animation_timeout_id = 0;
        }
    }

    private void finish_animation (string[] files) {
        set_loaded ();

        if (files.length > 1)
            background.set_blend (File.new_for_path (files[0]), File.new_for_path (files[1]), animation.transition_progress, style);
        else if (files.length > 0)
            background.set_file (File.new_for_path (files[0]), style);
        else
            background.set_file (null, style);

        queue_update_animation ();
    }

    private void update_animation () {
        update_animation_timeout_id = 0;

        animation.update (display.get_monitor_geometry (monitor_index));
        var files = animation.key_frame_files;

        var cache = Meta.BackgroundImageCache.get_default ();
        var num_pending_images = files.length;
        for (var i = 0; i < files.length; i++) {
            watch_file (files[i]);

            var image = cache.load (File.new_for_path (files[i]));

            if (image.is_loaded ()) {
                num_pending_images--;
                if (num_pending_images == 0) {
                    finish_animation (files);
                }
            } else {
                ulong handler = 0;
                handler = image.loaded.connect (() => {
                    image.disconnect (handler);
                    if (--num_pending_images == 0) {
                        finish_animation (files);
                    }
                });
            }
        }
    }

    private void queue_update_animation () {
        if (update_animation_timeout_id != 0)
            return;

        if (cancellable == null || cancellable.is_cancelled ())
            return;

        if (animation.transition_duration == 0)
            return;

        var n_steps = 255.0 / ANIMATION_OPACITY_STEP_INCREMENT;
        var time_per_step = (animation.transition_duration * 1000) / n_steps;

        var interval = (uint32) Math.fmax (ANIMATION_MIN_WAKEUP_INTERVAL * 1000, time_per_step);

        if (interval > uint32.MAX)
            return;

        update_animation_timeout_id = Timeout.add (interval, () => {
            update_animation_timeout_id = 0;
            update_animation ();
            return Source.REMOVE;
        });
    }

    private async void load_animation (string filename) {
        animation = yield BackgroundCache.get_default ().get_animation (filename);

        if (animation == null || cancellable.is_cancelled ()) {
            set_loaded ();
            return;
        }

        update_animation ();
        watch_file (filename);
    }

    private void load_image (string filename) {
        background.set_file (File.new_for_path (filename), style);
        watch_file (filename);

        var cache = Meta.BackgroundImageCache.get_default ();
        var image = cache.load (File.new_for_path (filename));
        if (image.is_loaded ())
            set_loaded ();
        else {
            ulong handler = 0;
            handler = image.loaded.connect (() => {
                set_loaded ();
                image.disconnect (handler);
            });
        }
    }

    private void load_file (string filename) {
        if (filename.has_suffix (".xml"))
            load_animation.begin (filename);
        else
            load_image (filename);
    }

    private void load () {
        load_pattern ();

        if (filename == null)
            set_loaded ();
        else
            load_file (filename);
    }

    private void settings_changed () {
        changed ();
    }
}
