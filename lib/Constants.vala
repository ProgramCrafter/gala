//
//  Copyright 2019 elementary, Inc. (https://elementary.io)
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

namespace Gala {
    [CCode (has_type_id = false)]
    public enum AnimationDuration {
        // Duration of the open animation
        OPEN = 350,
        // Duration of the close animation
        CLOSE = 195,
        // Duration of the hide animation
        HIDE = 200,
        // Duration of the menu mapping animation
        MENU_MAP = 150,
        // Duration of the snap animation as used by maximize/unmaximize
        SNAP = 250,
        // Duration of the workspace switch animation
        WORKSPACE_SWITCH_MIN = 300,
        WORKSPACE_SWITCH = 400,
        // Duration of the nudge animation when trying to switch to at the end of the workspace list
        NUDGE = 360,
    }

    public enum GestureAction {
        NONE,
        SWITCH_WORKSPACE,
        SWITCH_WINDOWS,
        MULTITASKING_VIEW,
        DOCK,
        ZOOM,
        CLOSE_WINDOW,
        N_ACTIONS
    }

    /**
     * Used as a key for Object.set_data<bool> on Meta.Windows that should be
     * treated as notifications. Has to be set before the window is mapped.
     */
    public const string NOTIFICATION_DATA_KEY = "elementary-notification";
}
