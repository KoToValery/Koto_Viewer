"""Build the original command SVGs, typed Flutter catalogue and bilingual gallery.

Run from the repository root: python tools/generate_command_icons.py
Geometry is authored here, not traced from a font or fetched from a service.
"""
from pathlib import Path
import html
import json
import re

ROOT = Path(__file__).resolve().parents[1]
ICONS = {}
ALIASES = {}


def path(d):
    return f'<path d="{d}"/>'


def rect(x, y, w, h, radius=0):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{radius}"/>'


def circle(x, y, radius):
    return f'<circle cx="{x}" cy="{y}" r="{radius}"/>'


def add(name, geometry, aliases=''):
    assert name not in ICONS, name
    ICONS[name] = dict(geometry=geometry)
    ALIASES.setdefault(name, name)
    for alias in aliases.split():
        ALIASES[alias] = name


P = path
R = rect
C = circle
doc = P('M6 3h8l4 4v14H6Z M14 3v5h4')
folder = P('M3 6h7l2 2h9v12H3Z')
cube = P('m12 3 9 5v9l-9 5-9-5V8Z M3 8l9 5 9-5 M12 13v9')
grid = R(3, 3, 18, 18, 1) + P('M3 9h18 M3 15h18 M9 3v18 M15 3v18')
table = R(3, 4, 18, 16, 1) + P('M3 9h18 M3 14h18 M9 4v16 M15 9v11')
eye = P('M2.5 12s3.5-6 9.5-6 9.5 6 9.5 6-3.5 6-9.5 6-9.5-6-9.5-6Z') + C(12, 12, 2.5)
pin = P('M18 9c0 4-6 12-6 12S6 13 6 9a6 6 0 1 1 12 0Z') + C(12, 9, 2)
plus = P('M12 5v14 M5 12h14')
minus = P('M5 12h14')
check = P('m5 12 4.5 4.5L19 7')
cross = P('m6 6 12 12 M18 6 6 18')
pencil = P('m4 16 11-11 4 4L8 20H4Z M13 7l4 4 M4 16l4 4')
gear = P('m9 3 1 3h4l1-3 3 2-1 3 2 3 3 1v3l-3 1-2 3 1 3-3 2-1-3h-4l-1 3-3-2 1-3-2-3-3-1v-3l3-1 2-3-1-3Z') + C(12, 13, 3)

# General actions and navigation.
add('add', plus)
add('remove', minus)
add('close', cross, 'clear')
add('confirm', check, 'check')
add('add_box', R(3, 3, 18, 18, 1) + plus)
add('add_circle', C(12, 12, 9) + plus, 'add_circle_outline')
add('remove_circle', C(12, 12, 9) + minus, 'remove_circle_outline')
add('check_box', R(3, 3, 18, 18, 1) + check)
add('check_box_empty', R(3, 3, 18, 18, 1), 'check_box_outline_blank')
add('remove_box', R(3, 3, 18, 18, 1) + minus, 'indeterminate_check_box')
add('check_circle', C(12, 12, 9) + check, 'check_circle_outline')
add('radio_on', C(12, 12, 9) + '<circle cx="12" cy="12" r="3" fill="currentColor" stroke="none"/>', 'radio_button_checked')
add('radio_off', C(12, 12, 9), 'radio_button_off radio_button_unchecked circle')
add('back', P('M20 12H4 m7-7-7 7 7 7'), 'arrow_back')
add('forward', P('M4 12h16 m-7-7 7 7-7 7'), 'arrow_forward')
add('up', P('M12 20V4 m-7 7 7-7 7 7'), 'arrow_upward')
add('down', P('M12 4v16 m-7-7 7 7 7-7'), 'arrow_downward south')
add('chevron_left', P('m15 5-7 7 7 7'), 'arrow_back_ios')
add('chevron_right', P('m9 5 7 7-7 7'), 'arrow_forward_ios keyboard_arrow_right')
add('expand_less', P('m5 15 7-7 7 7'), 'keyboard_arrow_up')
add('expand_more', P('m5 9 7 7 7-7'), 'keyboard_arrow_down arrow_drop_down')
add('first_page', P('M5 5v14 m12-14-7 7 7 7'), 'keyboard_double_arrow_left')
add('last_page', P('M19 5v14 M7 5l7 7-7 7'), 'keyboard_double_arrow_right')
add('outward', P('M5 19 19 5 M6 5h13v13'), 'arrow_outward')
add('diagonal_down', P('M5 5 19 19 M6 19h13V6'), 'south_east')
add('more_horizontal', C(5, 12, 1) + C(12, 12, 1) + C(19, 12, 1), 'more_horiz')
add('more_vertical', C(12, 5, 1) + C(12, 12, 1) + C(12, 19, 1), 'more_vert')
add('search', C(10, 10, 6) + P('m15 15 6 6'))
add('search_off', C(10, 10, 6) + P('m15 15 6 6 m-14-14 6 6 m0-6-6 6'))
add('zoom_in', C(10, 10, 6) + P('m15 15 6 6 M7 10h6 M10 7v6'))
add('zoom_out', C(10, 10, 6) + P('m15 15 6 6 M7 10h6'))
add('refresh', P('M20 9a8 8 0 1 0 0 7 M20 3v6h-6'), 'restart_alt restore')
add('sync', P('M3 9a9 9 0 0 1 16-3 l2 3h-6 M21 15a9 9 0 0 1-16 3 l-2-3h6 M3 9V3 M21 15v6'))
add('sync_problem', P('M3 9a9 9 0 0 1 16-3 l2 3h-6 M21 15a9 9 0 0 1-16 3 l-2-3h6 M12 8v5 M12 17v.1'))
add('undo', P('M4 10h10a6 6 0 0 1 0 12 M9 5l-5 5 5 5'))
add('redo', P('M20 10H10a6 6 0 0 0 0 12 M15 5l5 5-5 5'))
add('history', P('M3 11a9 9 0 1 1 2 7 M3 5v6h6 M12 7v6l4 2'), 'access_time schedule')
add('settings', gear)
add('properties', P('M3 6h5 m4 0h9 M3 12h11 m4 0h3 M3 18h3 m4 0h11') + C(10, 6, 2) + C(16, 12, 2) + C(8, 18, 2), 'tune')
add('info', C(12, 12, 9) + P('M12 11v6 M12 7v.1'), 'info_outline')
add('help', C(12, 12, 9) + P('M9 9a3 3 0 1 1 5 2c-2 1-2 1-2 3 M12 17v.1'), 'help_outline')
add('warning', P('M12 3 22 21H2Z M12 9v5 M12 18v.1'), 'warning_amber')
add('error', C(12, 12, 9) + P('M12 7v6 M12 17v.1'), 'error_outline')
add('filter', P('M3 4h18l-7 8v7l-4 2v-9Z'), 'filter_alt')
add('filter_off', P('M3 4h18l-7 8v7l-4 2v-9Z M3 3l18 18'), 'filter_alt_off')
add('filter_list', P('M3 6h18 M6 12h12 M9 18h6'))
add('sort', P('M4 5v14 m-3-3 3 3 3-3 M10 5h11 M10 10h8 M10 15h5 M10 20h2'))
add('drag', ''.join(C(x, y, .8) for x in (9, 15) for y in (5, 12, 19)), 'drag_indicator')
add('clear_all', P('M4 5h16 M7 10h13 M10 15h10 M13 20h7 M3 14l5 7 m0-7-5 7'))
add('backspace', P('M9 5h12v14H9l-7-7Z m3 4 7 7 m0-7-7 7'))
add('select', P('m5 3 14 10-7 1-3 7Z'), 'near_me ads_click touch_app')
add('select_all', R(7, 7, 10, 10) + P('M3 7V3h4 M17 3h4v4 M21 17v4h-4 M7 21H3v-4'))
add('deselect', P('M3 7V3h4 M17 3h4v4 M21 17v4h-4 M7 21H3v-4 m5-9 8 8 m0-8-8 8'))
add('multi_select', R(3, 3, 13, 13, 1) + P('M20 8v12H8 M6 9l3 3 5-6'), 'library_add_check')
add('pan', P('M7 13V7a1.5 1.5 0 0 1 3 0v5-8a1.5 1.5 0 0 1 3 0v8-7a1.5 1.5 0 0 1 3 0v8-5a1.5 1.5 0 0 1 3 0v7c0 4-2 6-6 6h-2c-2 0-3-1-4-3l-4-5a1.5 1.5 0 0 1 2-2Z'), 'pan_tool')
add('move', P('M12 2v20 M2 12h20 m-13-7 3-3 3 3 M9 19l3 3 3-3 M5 9l-3 3 3 3 m14-6 3 3-3 3'), 'open_with')
add('move_transverse', P('M4 4v16 M9 12h12 m-3-3 3 3-3 3 M13 8v8 M4 20h5'))
add('duplicate', R(8, 8, 13, 13, 1) + P('M16 4H4v12'), 'copy copy_all file_copy')
add('edit', pencil, 'draw drive_file_rename')
add('rename', P('M3 6h9 M3 12h6 M3 18h5 m5-13 5 0 m-2.5 0v14 m-2.5 0h5'))
add('delete', P('M3 6h18 M9 6V3h6v3 M6 6l1 15h10l1-15 M10 10v7 M14 10v7'), 'delete_outline')
add('delete_all', P('M2 7h13 M6 7V4h5v3 M4 7l1 14h7l1-14 M17 9h5 M17 13h4 M17 17h3'), 'delete_sweep')
add('rotate', P('M19 9a8 8 0 1 0 1 7 M19 3v6h-6') + R(8, 10, 6, 6), 'rotate_right')
add('rotate_left', P('M5 9a8 8 0 1 1-1 7 M5 3v6h6') + R(10, 10, 6, 6), 'rotate_90_degrees_ccw')
add('mirror_move', P('M12 3v2 m0 3v2 m0 3v2 m0 3v3 M4 7v10h4 M16 7l5 10h-5Z M5 4h14 m-3-2 3 2-3 2'))
add('mirror_copy', P('M12 3v2 m0 3v2 m0 3v2 m0 3v3 M3 17l5-10v10Z M16 7l5 10h-5Z'))
add('flip_horizontal', P('M12 3v3 m0 3v3 m0 3v3 m0 3v.1 M16 7l5 10h-5Z') + '<path d="M3 17l5-10v10Z" stroke-dasharray="2 2"/>', 'flip')
add('flip_vertical', P('M3 12h3 m3 0h3 m3 0h3 m3 0h.1 M7 3l10 5H7Z M7 16h10l-10 5Z'))
add('swap_horizontal', P('M3 8h18 m-4-4 4 4-4 4 M21 16H3 m4-4-4 4 4 4'), 'swap_horiz sync_alt')
add('swap_vertical', P('M8 3v18 m-4-4 4 4 4-4 M16 21V3 m-4 4 4-4 4 4'), 'swap_vert unfold_more')
add('split', P('M3 7h7v10H3 M14 7h7v10h-7 M12 3v3 m0 3v3 m0 3v3 m0 3v.1'), 'call_split')
add('cut', C(5, 6, 3) + C(5, 18, 3) + P('m7 8 14 13 M7 16 21 3'), 'content_cut')
add('cut_opening', P('M3 5h18v14H3Z M8 5v3 m0 3v3 m0 3v2 M16 5v3 m0 3v3 m0 3v2 M8 9h8 M8 15h8'), 'cut')
add('offset', P('M3 18V5h13 M8 22V10h13 M3 3h5 m-3-2-2 2 2 2 M15 14h6 m-3-3 3 3-3 3'))
add('new_point', C(12, 12, 7.5) + '<circle cx="12" cy="12" r="3" fill="currentColor" stroke="none"/>', 'adjust')
add('join', P('M5 3v8 M21 19h-8') + '<path d="M5 11v8h8" stroke-dasharray="1.5 2"/>', 'join_inner')
add('straighten', P('M3 18 8 7l6 9 7-10 M3 21h18 M6 3h12 m-9-2-3 2 3 2 m6-4 3 2-3 2'))
add('group', R(2.5, 2.5, 19, 19, 1) + R(6, 7, 6, 8) + R(14, 11, 4, 6), 'group_work')
add('ungroup', R(3, 4, 7, 10) + R(14, 11, 7, 10) + P('M10 5h7 M14 2l3 3-3 3 M14 19H7 m3-3-3 3 3 3'), 'workspaces')
add('edit_group', P('M12 3H3v18h7 M21 10V3h-5 m-4 14 7-7 3 3-7 7-4 1Z'), 'edit_note')

# File and application commands.
add('file', doc, 'description insert_drive_file article text_snippet')
add('open_file', doc + P('M9 14h9 m-3-3 3 3-3 3'), 'file_open')
add('folder', folder)
add('open_folder', P('M3 10V5h7l2 2h8v3 M3 10h19l-4 10H3Z'), 'folder_open')
add('new_folder', folder + P('M12 11v6 M9 14h6'), 'create_new_folder')
add('copy_folder', P('M3 16V3h6l2 2h7 M6 8h6l2 2h7v11H6Z'), 'folder_copy')
add('folder_off', folder + P('M3 3l18 18'))
add('folder_favorite', folder + P('m12 10 1.4 3 3.1.4-2.2 2.2.5 3.1-2.8-1.5-2.8 1.5.5-3.1-2.2-2.2 3.1-.4Z'), 'folder_special')
add('archive', R(3, 3, 18, 5, 1) + P('M5 8v13h14V8 M10 12h4'), 'folder_zip')
add('save', P('M3 3h15l3 3v15H3Z M7 3v6h10V3 M7 21v-8h10v8 M14 5v2'))
add('save_as', P('M3 3h15l3 3v5 M3 3v18h7 M7 3v6h10V3 m-5 14 7-7 3 3-7 7-4 1Z'))
add('download', P('M12 3v12 m-5-5 5 5 5-5 M3 17v4h18v-4'), 'file_download download_for_offline')
add('upload', P('M12 16V4 m-5 5 5-5 5 5 M3 17v4h18v-4'), 'file_upload upload_file cloud_upload')
add('print', P('M7 8V3h10v5 M6 17H3V8h18v9h-3 M7 14h10v7H7Z M17 11h1'))
add('share', C(18, 5, 3) + C(5, 12, 3) + C(18, 19, 3) + P('m8 10 7-4 M8 14l7 4'))
add('link', P('m9 15 6-6 M8 16l-1 1a4 4 0 0 1-6-6l4-4a4 4 0 0 1 6 0 M16 8l1-1a4 4 0 0 1 6 6l-4 4a4 4 0 0 1-6 0'))
add('unlink', P('M8 16l-1 1a4 4 0 0 1-6-6l4-4 M16 8l1-1a4 4 0 0 1 6 6l-4 4 M4 3l16 18'), 'link_off')
add('external', P('M13 3h8v8 M21 3 10 14 M10 5H3v16h16v-7'), 'open_in_new')
add('theme_dark', P('M20 15A9 9 0 0 1 9 4a9 9 0 1 0 11 11Z'), 'dark_mode')
add('theme_light', C(12, 12, 4) + P('M12 2v2 M12 20v2 M2 12h2 M20 12h2 M5 5l1.5 1.5 M17.5 17.5 19 19 M5 19l1.5-1.5 M17.5 6.5 19 5'), 'light_mode')
add('theme_auto', C(12, 12, 8) + P('M12 4a8 8 0 0 1 0 16Z'), 'brightness_6')
add('language', P('M3 5h12 M9 3v2 M5 5c1 6 4 8 8 11 M13 5c-1 6-4 8-10 11 M14 21l4-10 4 10 M15.5 18h5'), 'translate')
add('update', R(6, 2, 12, 20, 2) + P('M12 17V7 m-3 3 3-3 3 3 M10 20h4'), 'system_update')
add('bug', R(7, 7, 10, 13, 4) + P('M9 7V4h6v3 M3 8l4 3 M21 8l-4 3 M2 14h5 M17 14h5 M3 21l5-3 M21 21l-5-3 M12 10v7'), 'bug_report')
add('home', P('m2 11 10-8 10 8 M5 9v12h14V9 M10 21v-7h4v7'))
add('favorite', P('M12 21 3 12C-2 5 7-1 12 6c5-7 14-1 9 6Z'))
add('star', P('m12 2 3 6.5 7 1-5 5 1.2 7L12 18l-6.2 3.5L7 14.5l-5-5 7-1Z'), 'star_border')
add('bookmark', P('M6 3h12v19l-6-4-6 4Z'), 'bookmark_border')
add('bookmark_add', P('M6 3h12v19l-6-4-6 4Z M9 9h6 M12 6v6'))
add('bookmarks', P('M3 3h12v16l-6-4-6 4Z M18 6h3v16l-5-3'))
add('email', R(2, 4, 20, 16, 1) + P('m2 5 10 8L22 5'))
add('wifi', P('M2 7a16 16 0 0 1 20 0 M5 11a11 11 0 0 1 14 0 M8 15a6 6 0 0 1 8 0') + C(12, 20, 1), 'wifi_tethering')
add('wifi_off', P('M3 7a16 16 0 0 1 18-1 M6 11a11 11 0 0 1 12 0 M9 15a6 6 0 0 1 6 0 M3 3l18 18') + C(12, 20, 1))
add('computer', R(2, 3, 20, 14, 1) + P('M12 17v4 M7 21h10'), 'laptop_mac')
add('storage', P('M7 2h12v20H5V4Z M8 2v7h8V2 M9 16h6 M9 19h6'), 'sd_storage')
add('payment', R(2, 4, 20, 16, 2) + P('M2 9h20 M5 15h4 M12 15h3'), 'credit_card')
add('security', P('m12 2 9 4v6c0 5-5 8-9 10-4-2-9-5-9-10V6Z'), 'shield')
add('verified', P('m12 2 9 4v6c0 5-5 8-9 10-4-2-9-5-9-10V6Z m-5 9 3 3 6-7'), 'verified_user')
add('lock', R(4, 10, 16, 12, 2) + P('M7 10V7a5 5 0 0 1 10 0v3 M12 15v3'))
add('unlock', R(4, 10, 16, 12, 2) + P('M7 10V7a5 5 0 0 1 9-3 M12 15v3'), 'lock_open')

# Drawing and BIM tools.
add('wall', P('M3 5h18v14H3Z M8 5v6 M16 5v6 M3 11h18 M7 11v8 M15 11v8'), 'line_weight')
add('door', P('M3 21V3h10v18 M13 3a18 18 0 0 1 8 15 M13 21l8-3 M9 12h.1'), 'meeting_room door_front_door')
add('window', R(3, 4, 18, 16) + P('M6 4v16 M18 4v16 M6 12h12 M12 4v16'))
add('column', R(6, 5, 12, 14) + P('M3 2h5 M2 3v5 M16 2h5v6 M2 16v6h6 M16 22h6v-6'), 'view_column')
add('beam', P('M3 7h18v3H3Z M10 10v4 M14 10v4 M3 14h18v3H3Z M5 20h14'), 'horizontal_rule')
add('slab', P('m3 8 12-4 6 4-12 4Z M3 8v7l6 4 12-4V8 M9 12v7'))
add('opening', P('M3 7V3h4 M17 3h4v4 M21 17v4h-4 M7 21H3v-4') + R(7, 7, 10, 10), 'crop_free tab_unselected')
add('roof', P('m2 13 10-10 10 10 M5 10v11h14V10 M8 7l8 8 M12 3l7 7 M7 21v-5h5v5'), 'roofing')
add('stairs', P('M3 21v-5h5v-5h5V6h5V2 M3 21h18V2 M4 12l12-9 m-5 0h5v5'))
add('axis', P('M12 8v4 m0 3v4 m0 2v1 M3 14h4 m3 0h4 m3 0h4') + C(12, 4, 3), 'grid_3x3')
add('section', P('M4 3v18 M20 3v18 M4 12h16 M4 6l5 3-5 3 M20 18l-5-3 5-3'), 'splitscreen')
add('elevation', P('M3 21V9l9-6 9 6v12Z M3 10h18 M7 14h3v3H7Z M14 14h3v3h-3Z M10 21v-2h4v2'))
add('building', R(5, 3, 14, 18) + P('M9 7h1 M14 7h1 M9 11h1 M14 11h1 M9 15h1 M14 15h1 M10 21v-3h4v3'), 'apartment business domain')
add('new_building', P('M3 21V3h12v8 M7 7h1 M11 7h1 M7 12h1 M7 17h1 M18 13v9 M14 17h8'), 'add_business add_home_work')
add('building_off', R(5, 3, 14, 18) + P('M9 7h1 M14 7h1 M9 11h1 M14 11h1 M9 15h1 M14 15h1 M3 3l18 18'), 'domain_disabled')
add('storeys', P('M3 5h18 M3 12h18 M3 19h18 M6 3v18 M18 3v18 M9 8h6 M9 15h6'))
add('zone', P('M3 3h18v18H3Z M3 9h7v12 M10 13h11 M14 3v10'), 'space_dashboard dashboard')
add('schedule', table, 'table_chart table_view assessment list_alt')
add('zone_schedule', table + P('M6 6h.1 M6 11h.1 M6 16h.1'))
add('dimension', P('M4 3v18 M20 3v18 M4 12h16 M2 14l4-4 m12 4 4-4 M8 6h8'))
add('level', P('M3 12h18 M7 5l5 7 5-7Z M12 12v8 M8 20h8'), 'change_history height')
add('measure', P('M3 6h18v12H3Z M7 6v5 M11 6v3 M15 6v5 M19 6v3'), 'straighten square_foot')
add('measure_area', P('M3 3h15v6h3v12H3Z M7 8l10 10 M11 18h6v-6'))
add('measure_angle', P('M3 21h18 M3 21 14 3 M9 21a6 6 0 0 0-3-5'), 'architecture')
add('measure_radius', C(12, 12, 9) + P('m12 12 6-6 m-4 0h4v4'))
add('line', P('M4 19 20 5') + R(2, 17, 4, 4) + R(18, 3, 4, 4), 'show_chart timeline')
add('polyline', P('M3 18 9 5l8 11 4-12') + C(3, 18, 1.5) + C(9, 5, 1.5) + C(17, 16, 1.5) + C(21, 4, 1.5))
add('rectangle', R(3, 5, 18, 14), 'crop_square')
add('hatch', R(3, 3, 18, 18) + P('M3 9 9 3 M3 16 16 3 M5 21 21 5 M12 21l9-9 M19 21l2-2'), 'texture')
add('text', P('M4 6V3h16v3 M12 3v18 M8 21h8'), 'title text_fields font_download')
add('text_size', P('M3 18 8 5l5 13 M5 13h6 M15 10h7 M18.5 10v10'), 'format_size')
add('text_increase', P('M2 20 8 4l6 16 M4 14h8 M18 4v8 M14 8h8'))
add('text_decrease', P('M2 20 8 4l6 16 M4 14h8 M15 8h7'))
add('align_left', P('M3 3v18 M7 5h14 M7 10h9 M7 15h14 M7 20h9'), 'align_horizontal_left format_align_left')
add('align_center', P('M12 2v20 M3 5h18 M6 10h12 M3 15h18 M6 20h12'), 'align_horizontal_center vertical_align_center')
add('align_top', P('M3 3h18 M8 7v14 M16 7v9 M5 10l3-3 3 3 m2 0 3-3 3 3'), 'vertical_align_top')
add('align_bottom', P('M3 21h18 M8 17V3 M16 17V8 M5 14l3 3 3-3 m2 0 3 3 3-3'), 'vertical_align_bottom')
add('layers', P('m2 8 10-5 10 5-10 5Z M3 12l9 5 9-5 M3 16l9 5 9-5'))
add('layers_off', P('m4 7 8-4 10 5-8 4 M3 12l9 5 9-5 M3 16l9 5 6-3 M3 3l18 18'), 'layers_clear')
add('grid', grid, 'grid_on grid_4x4')
add('grid_off', grid + P('M2 2l20 20'))
add('terrain', P('m2 20 7-15 5 8 3-5 5 12Z M7 9l4 4 2-2'), 'landscape')
add('floor_drain', R(4, 4, 16, 16) + C(12, 12, 5) + P('M7 12h10 M12 7v10 M9 8l6 8 M15 8l-6 8'))
add('water', P('M12 2C9 7 5 11 5 15a7 7 0 0 0 14 0c0-4-4-8-7-13Z M8 15a4 4 0 0 0 4 4'), 'water_drop')
add('foundation', P('M8 3h8v12h4v6H4v-6h4Z M2 21h20 M6 17l-2 2 M11 16l-5 5 M16 16l-5 5 M20 17l-4 4'))
add('wall_joint', P('M3 7h6V3h6v6h6v6h-6v6H9V13H3Z'), 'merge_type')
add('rounded_corner', P('M3 21V10a7 7 0 0 1 7-7h11 M8 21V11a3 3 0 0 1 3-3h10'))
add('line_style', P('M3 5h18 M3 12h4 m4 0h4 m4 0h2 M3 19h1 m4 0h1 m4 0h1 m4 0h1'), 'border_style')
add('line_weight', P('M3 4h18 M3 9h18') + '<path d="M3 15h18" stroke-width="3"/>' + '<path d="M3 21h18" stroke-width="4"/>', 'density_medium density_small view_headline')
add('points', P('M3 12h18') + C(5, 12, 2) + C(19, 12, 2), 'linear_scale')
add('magnet', P('M4 3v10a8 8 0 0 0 16 0V3h-5v10a3 3 0 0 1-6 0V3Z M4 7h5 M15 7h5'), 'track_changes')
add('gesture', P('M3 19c-4-6 16-23 13-14S-2 22 8 18 25 5 20 13s-7 11-8 7'), 'gesture')
add('component', cube, 'widgets token')
add('furniture', P('M5 11V4h14v7 M3 10h4v6h10v-6h4v9H3Z M5 19v3 M19 19v3'), 'chair weekend')
add('bed', P('M3 21V7h18v14 M3 16h18 M3 11h18 M6 7V4h12v3 M7 11v5 M17 11v5'))
add('bath', P('M2 12h20 M4 12v5a3 3 0 0 0 3 3h10a3 3 0 0 0 3-3v-5 M6 20v2 M18 20v2 M5 12V5a3 3 0 0 1 6 0 M8 5h5'), 'bathtub')
add('kitchen', R(5, 2, 14, 20, 1) + P('M5 10h14 M8 5v2 M8 14v4'))
add('balcony', P('M3 10h18 M3 20h18 M5 10v10 M10 10v10 M15 10v10 M20 10v10 M4 4h16'), 'deck')
add('fence', P('M3 8 6 4l3 4v14H3Z M15 8l3-4 3 4v14h-6Z M9 12h6 M9 18h6'))
add('cabin', P('m2 10 10-8 10 8 M5 8v14h14V8 M5 12h14 M5 16h14 M5 20h14'))
add('tree', P('m12 2-8 9h4l-6 7h8v4h4v-4h8l-6-7h4Z'), 'nature_people')
add('analysis', P('M3 3v18h18 M7 17v-5h3v5 M13 17V8h3v9 M19 17V5h2v12'), 'analytics')
add('seismic', P('M2 14h4l2-7 4 14 4-18 2 11h4'), 'waves')
add('bolt', P('M14 2 4 14h7l-1 8 10-12h-7Z'))
add('engineering', P('M4 21V8h16v13 M8 8V4h8v4 M2 21h20 M8 12h8 M8 16h8'), 'precision_manufacturing developer_board memory')
add('graph', R(8, 2, 8, 5) + R(2, 17, 7, 5) + R(15, 17, 7, 5) + P('M12 7v5 M5.5 17v-5h13v5'), 'account_tree schema hub')
add('chart', P('M3 3v18h18 M5 16l5-8 5 4 6-9'), 'scatter_plot')

# View, document, image and media commands.
add('view_3d', cube + P('m7 6 10 6'), 'view_in_ar')
add('orbit', C(12, 12, 4) + P('M3 9c0-7 18-7 18 3S3 22 3 14 M3 5v4h4'), 'threed_rotation')
add('fly', P('m2 17 20-7-8-3-4-5-3 1 3 7-8 4Z M3 22h18'), 'flight_takeoff')
add('view_top', cube + '<path d="m12 3 9 5-9 5-9-5Z" fill="currentColor" fill-opacity=".2"/>')
add('view_front', cube + '<path d="m3 8 9 5v9l-9-5Z" fill="currentColor" fill-opacity=".2"/>', 'flip_to_front')
add('view_right', cube + '<path d="m12 13 9-5v9l-9 5Z" fill="currentColor" fill-opacity=".2"/>')
add('view_bottom', cube + P('M7 20h10'))
add('view_back', cube + '<path d="m3 17 9-5 9 5 M12 3v9" stroke-dasharray="2 2"/>', 'flip_to_back')
add('visible', eye, 'visibility remove_red_eye')
add('hidden', eye + P('M3 3l18 18'), 'visibility_off')
add('fit_view', P('M3 8V3h5 M16 3h5v5 M21 16v5h-5 M8 21H3v-5') + R(7, 8, 10, 8), 'fit_screen center_focus_strong center_focus_weak filter_center_focus')
add('fullscreen', P('M3 9V3h6 M15 3h6v6 M21 15v6h-6 M9 21H3v-6'), 'open_in_full')
add('exit_fullscreen', P('M9 3v6H3 M21 9h-6V3 M15 21v-6h6 M3 15h6v6'), 'fullscreen_exit close_fullscreen')
add('aspect_ratio', R(2, 5, 20, 14, 1) + P('M5 11V8h4 M15 16h4v-3'), 'photo_size_select_actual')
add('portrait', R(6, 2, 12, 20, 1) + P('M10 19h4'), 'crop_portrait')
add('screen_rotate', P('m5 8 7-5 8 12-7 5Z M3 8V3h5 M21 16v5h-5'), 'screen_rotation')
add('screen_lock', R(3, 7, 18, 14, 1) + P('M8 7V5a4 4 0 0 1 8 0v2 M12 13v3'), 'screen_lock_rotation screen_lock_landscape')
add('compare', R(3, 5, 18, 14) + P('M12 2v20 M6 15l3-4 3 4 M15 9h3'))
add('crop', P('M7 2v15h15 M2 7h15v15 M7 7l10 10'))
add('opacity', P('M12 2C9 7 5 11 5 15a7 7 0 0 0 14 0c0-4-4-8-7-13Z M12 2v20'))
add('image', R(2, 3, 20, 18, 1) + C(8, 8, 2) + P('m2 18 6-6 4 4 4-6 6 8'), 'photo photo_library')
add('image_add', P('M13 3H2v18h20V11 M2 18l6-6 4 4 4-6 M18 2v7 M14.5 5.5h7'), 'add_to_photos')
add('image_filter', R(2, 5, 17, 16, 1) + P('m2 18 5-5 4 4 4-6 4 5 M19 1v7 M15.5 4.5h7'), 'photo_filter')
add('image_broken', R(2, 3, 20, 18, 1) + P('m2 17 6-5 4 4 4-5 6 6 M3 3l18 18'), 'broken_image')
add('camera', P('M2 7h5l2-4h6l2 4h5v14H2Z') + C(12, 13, 4), 'camera_alt')
add('palette', P('M12 3a9 9 0 1 0 0 18h2c4 0 4-5 0-5h-1c-2 0-2-3 0-3h4c7 0 4-10-5-10Z') + C(6.5, 11, 1) + C(9, 6.5, 1) + C(14, 6.5, 1) + C(18, 10, 1))
add('fill', P('m4 10 8-8 8 8-8 8Z M8 2l8 8 M4 10h16 M21 14c-3 4-3 6 0 6s3-2 0-6 M3 22h18'), 'format_color_fill')
add('brush', P('m10 12 9-10 3 3-10 9Z M10 12c-5-2-4 6-8 8 7 3 13-3 8-8Z'))
add('pixelated', R(3, 3, 5, 5) + R(10, 10, 5, 5) + R(17, 3, 4, 5) + R(3, 17, 5, 4) + R(17, 17, 4, 4), 'grain')
add('smooth', P('M3 5h18 M3 9h18 M3 13h18 M3 17h18 M3 21h18'), 'blur_linear lens_blur')
add('book', P('M12 5c-3-2-6-2-10-1v16c4-1 7-1 10 1 3-2 6-2 10-1V4c-4-1-7-1-10 1Z M12 5v16'), 'menu_book auto_stories')
add('library', P('M3 3h5v18H3Z M10 3h5v18h-5Z m7 2 4-1 3 16-4 1Z'), 'library_books')
add('book_closed', P('M5 3h15v18H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2Z M5 3v14h15 M3 19h17'), 'book')
add('notes', P('M3 4h18 M3 9h18 M3 14h18 M3 19h11'), 'notes')
add('comment', P('M3 3h18v14H9l-6 5Z M7 7h10 M7 12h7'), 'chat_bubble')
add('list', P('M8 5h13 M8 12h13 M8 19h13') + C(3, 5, 1) + C(3, 12, 1) + C(3, 19, 1), 'format_list_bulleted')
add('numbered_list', P('M8 5h13 M8 12h13 M8 19h13 M2 3h2v4 M2 11h3l-3 3h3 M2 18h3v4H2 m0-2h3'), 'format_list_numbered')
add('checklist', P('m2 5 2 2 3-4 M10 5h12 m-20 8 2 2 3-4 M10 13h12 m-20 8 2 2 3-4 M10 21h12'))
add('wrap_text', P('M3 5h18 M3 10h14a4 4 0 0 1 0 8h-5 m3-3-3 3 3 3 M3 16h5 M3 21h5'))
add('line_spacing', P('M4 3v18 m-3-15 3-3 3 3 m-6 12 3 3 3-3 M10 4h11 M10 12h11 M10 20h11'), 'format_line_spacing')
add('table', table, 'table_rows')
add('pdf', doc + P('M9 17c6-11 3-11 3-6 0 5 7 6 5 4-2-2-10 4-8 2'), 'picture_as_pdf')
add('code', P('m8 5-6 7 6 7 M16 5l6 7-6 7 M14 3l-4 18'), 'data_object developer_mode')
add('code_off', P('m8 5-6 7 6 7 M16 5l6 7-6 7 M3 3l18 18'))
add('functions', P('M18 3H6l7 9-7 9h12 M6 3H4 M6 21H4'))
add('watermark', R(2, 4, 20, 16, 1) + R(12, 12, 7, 5), 'branding_watermark')
add('layout_grid', R(3, 3, 7, 7, 1) + R(14, 3, 7, 7, 1) + R(3, 14, 7, 7, 1) + R(14, 14, 7, 7, 1), 'grid_view apps category dialpad')
add('layout_rows', R(3, 3, 18, 7, 1) + R(3, 14, 18, 7, 1), 'view_agenda view_stream view_day')
add('layout_sidebar', R(2, 3, 20, 18, 1) + P('M8 3v18 M4.5 7h1 M4.5 11h1 M4.5 15h1'), 'view_sidebar menu_open')
add('layout_carousel', R(6, 3, 12, 18, 1) + P('M2 6v12 M22 6v12'), 'view_carousel')
add('layout_custom', R(3, 3, 7, 7) + R(14, 3, 7, 7) + R(3, 14, 7, 7) + P('M17.5 14v7 M14 17.5h7'), 'dashboard_customize auto_awesome_mosaic')
add('play', P('m7 3 15 9-15 9Z'), 'play_arrow')
add('play_circle', C(12, 12, 10) + P('m9 7 8 5-8 5Z'), 'play_circle_fill play_circle_filled play_circle_outline')
add('pause', R(6, 3, 3, 18) + R(15, 3, 3, 18))
add('pause_circle', C(12, 12, 10) + P('M9 7v10 M15 7v10'), 'pause_circle_filled')
add('stop', R(5, 5, 14, 14, 1))
add('stop_circle', C(12, 12, 10) + R(8, 8, 8, 8))
add('next_track', P('m3 4 13 8-13 8Z M20 4v16'), 'skip_next')
add('previous_track', P('m21 4-13 8 13 8Z M4 4v16'), 'skip_previous')
add('fast_forward', P('m2 5 10 7-10 7Z m11 0 10 7-10 7Z'))
add('fast_rewind', P('m22 5-10 7 10 7Z m-11 0-10 7 10 7Z'))
add('forward_ten', P('M20 9a8 8 0 1 0 0 7 M20 3v6h-6 M7 11v6') + R(11, 11, 4, 6, 2), 'forward_10')
add('replay_ten', P('M4 9a8 8 0 1 1 0 7 M4 3v6h6 M7 11v6') + R(11, 11, 4, 6, 2), 'replay_10')
add('repeat', P('M3 10V5h18 m-4-3 4 3-4 3 M21 14v5H3 m4-3-4 3 4 3'), 'repeat_on')
add('repeat_one', P('M3 10V5h18 m-4-3 4 3-4 3 M21 14v5H3 m4-3-4 3 4 3 M10 10l2-1v6'), 'repeat_one_on')
add('volume', P('M3 9h4l5-5v16l-5-5H3Z M16 8a6 6 0 0 1 0 8 M19 4a11 11 0 0 1 0 16'), 'volume_up')
add('mute', P('M3 9h4l5-5v16l-5-5H3Z m13-8 6 6 m0-6-6 6'), 'volume_off')
add('video', R(2, 5, 13, 14, 1) + P('m15 9 7-4v14l-7-4Z'), 'videocam')
add('presentation', R(3, 3, 18, 14) + P('m10 7 6 3-6 3Z M12 17v5 M7 22h10'), 'slideshow')
add('animation', C(8, 16, 5) + C(12, 12, 6) + P('M8 4a8 8 0 1 1 12 10'))

# Maps, measurements and auxiliary command categories.
add('map', P('m2 5 7-3 6 3 7-3v17l-7 3-6-3-7 3Z M9 2v17 M15 5v17'))
add('location', pin, 'location_on place')
add('location_add', pin + P('M9 9h6 M12 6v6'), 'add_location_alt')
add('location_edit', P('M12 21S6 13 6 9a6 6 0 0 1 11-3 M13 14l6-6 3 3-6 6-4 1Z'), 'edit_location_alt')
add('locate', C(12, 12, 6) + C(12, 12, 2) + P('M12 2v4 M12 18v4 M2 12h4 M18 12h4'), 'my_location location_searching')
add('compass', C(12, 12, 10) + P('m16 8-2 6-6 2 2-6Z'), 'explore')
add('globe', C(12, 12, 10) + P('M2 12h20 M12 2c-6 5-6 15 0 20 6-5 6-15 0-20Z'), 'public')
add('route', C(5, 4, 2) + C(19, 20, 2) + P('M5 6v7a4 4 0 0 0 8 0V9a4 4 0 0 1 8 0v8'))
add('alternative_route', P('M7 22V9L3 5 m0 4V5h4 M7 14l10-9 m-4 0h4v4'), 'alt_route')
add('turn_left', P('M19 21V10H4 m5-5-5 5 5 5'))
add('turn_right', P('M5 21V10h15 m-5-5 5 5-5 5'))
add('flag', P('M4 22V3c5-4 10 4 16 0v11c-6 4-11-4-16 0'))
add('finish', P('M4 22V3h16v11H4 M4 3l16 11 M20 3 4 14'), 'sports_score')
add('walk', C(13, 3.5, 2) + P('m7 21 4-8-1-5 4 3 4 1 M11 13l5 8 M10 8l-4 4 M16 7l3 7'), 'hiking')
add('bicycle', C(5, 16, 4) + C(19, 16, 4) + P('m5 16 5-9 5 9H5 M13 4h4 M15 4l4 12 M8 7h5'), 'directions_bike')
add('tag', P('M3 3h8l11 11-8 8L3 11Z') + C(7, 7, 1), 'badge')
add('pin', P('M8 3h8 M9 3v7l-3 4v2h12v-2l-3-4V3 M12 16v6'))
add('calendar', R(3, 5, 18, 16, 1) + P('M3 10h18 M7 2v6 M17 2v6 M7 14h3 M14 14h3 M7 18h3'), 'date_range')
add('medical', R(3, 6, 18, 15, 1) + P('M8 6V3h8v3 M12 10v7 M8.5 13.5h7'), 'medical_services')
add('fingerprint', P('M5 18c-2-10 1-15 7-15s9 5 7 15 M8 21c-2-10-1-15 4-15s6 5 4 15 M12 9c-2 0-2 3-1 6s1 5 0 7 M14 11v4'))
add('auto', P('m5 21 13-15 3 3L8 23Z M15 3V1 M20 4l2-2 M22 9h2 M5 3v6 M2 6h6'), 'auto_awesome auto_fix_high')
add('science', P('M8 2h8 M10 2v8L3 21h18l-7-11V2 M7 15h10'))
add('rocket', P('M9 15C7 8 14 1 21 3c2 7-5 14-12 12Z M9 9H4l-2 8 7-2 M15 15v5l-8 2 2-7 M5 19l-3 3') + C(16, 8, 2), 'rocket_launch')
add('inventory', P('M3 5h18v16H3Z M2 2h20v5H2Z M9 12h6'), 'inventory_2')
add('balance', P('m2 7 10-5 10 5Z M4 9v10 M9 9v10 M15 9v10 M20 9v10 M2 22h20 M3 19h18'), 'account_balance')
add('web', R(2, 3, 20, 18, 1) + P('M2 8h20 M5 5h.1 M8 5h.1 M11 5h.1'), 'web_asset')
add('space', P('M3 8v8h18V8'), 'space_bar')
add('road_edit', P('M5 2v20 M14 2v7 M10 2v3 m0 3v3 m0 3v3 m0 3v2 m3-6 6-6 3 3-6 6-4 1Z'), 'edit_road')
add('lightbulb', P('M8 17c0-4-3-4-3-8a7 7 0 0 1 14 0c0 4-3 4-3 8Z M8 20h8 M10 23h4 M12 17v-6 m-3-3 3 3 3-3'))
add('align_right', P('M21 3v18 M3 5h14 M8 10h9 M3 15h14 M8 20h9'))
add('polygon', P('m3 6 11-3 7 8-6 10-12-5Z'))
add('arc', P('M3 20A17 17 0 0 1 20 3') + C(3, 20, 1.5) + C(20, 3, 1.5))
add('roof_gable', P('M2 17 12 5l10 12 M5 14v7h14v-7 M12 5v12'))
add('roof_hip', R(3, 4, 18, 16) + P('m3 4 6 8-6 8 M21 4l-6 8 6 8 M9 12h6'))
add('roof_shed', P('M2 13 22 4 M5 12v9h14V6 M5 17h14'))
add('roof_flat', P('M2 5h20v4H2Z M5 9v12h14V9'))
add('roof_mansard', P('m2 17 4-9 6-4 6 4 4 9 M5 14v7h14v-7 M6 8h12'))
add('selection_contained', R(3, 3, 18, 18) + R(8, 8, 8, 8))
add('selection_crossing', '<rect x="3" y="3" width="16" height="18" stroke-dasharray="2 2"/>' + R(12, 8, 10, 8))
add('shading_edges', cube)
add('shading_smooth', C(12, 12, 9) + P('M12 3c6 4 6 14 0 18 M16 5c6 4 6 10 0 14'))
add('shading_flat', P('m12 3 9 6-3 12H6L3 9Z M12 3l2 12-8 6 M14 15l7-6 M14 15l4 6 M3 9l11 6'))
add('shading_wire', cube + P('M3 8l18 9 M21 8 3 17'))
add('shading_xray', cube + '<path d="m3 17 9-5 9 5 M12 3v9" stroke-dasharray="2 2"/>')


def base_name(name):
    name = re.sub(r'_(rounded|outlined|sharp)$', '', name)
    return re.sub(r'_outline$', '', name)


def camel(name):
    bits = name.split('_')
    return bits[0] + ''.join(b.title() for b in bits[1:])


def message(name):
    return 'commandIcon' + ''.join(b.title() for b in name.split('_'))


def svg(geometry):
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" '
            'width="24" height="24" fill="none" stroke="currentColor" '
            'stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round">'
            + geometry + '</svg>\n')


def generate():
    # This explicit compatibility inventory includes data-driven controls that still
    # obtain their legacy IconData from file/category/renderer domain objects.
    legacy_file = ROOT / 'tools/command_icon_material_aliases.json'
    if legacy_file.exists():
        legacy = json.loads(legacy_file.read_text(encoding='utf-8'))
    else:
        legacy = sorted({n for f in (ROOT / 'lib').rglob('*.dart')
                         for n in re.findall(r'Icons\.([a-zA-Z0-9_]+)', f.read_text(encoding='utf-8'))})
    missing = sorted({base_name(n) for n in legacy if base_name(n) not in ALIASES})
    if missing:
        raise SystemExit('Missing authored geometry: ' + ', '.join(missing))
    arbs = {lang: json.loads((ROOT / f'lib/l10n/app_{lang}.arb').read_text(encoding='utf-8')) for lang in ('bg', 'en')}
    for lang, arb in arbs.items():
        for name in ICONS:
            if not isinstance(arb.get(message(name)), str):
                raise SystemExit(f'Missing ARB label: {lang}/{message(name)}')
    legacy_file.write_text(json.dumps(legacy, indent=2) + '\n', encoding='utf-8')
    assets = ROOT / 'assets/icons/commands'
    assets.mkdir(parents=True, exist_ok=True)
    for name, spec in ICONS.items():
        (assets / f'{name}.svg').write_text(svg(spec['geometry']), encoding='utf-8')
    names = sorted(ICONS)
    core = ROOT / 'lib/src/core/icons'
    core.mkdir(parents=True, exist_ok=True)
    enum = '\n'.join(f'  {camel(n)},' for n in names)
    paths = '\n'.join(f"    AppIconId.{camel(n)} => 'assets/icons/commands/{n}.svg'," for n in names)
    labels = '\n'.join(f'    AppIconId.{camel(n)} => l.{message(n)},' for n in names)
    mappings = '\n'.join(f'    MapEntry(Icons.{n}, AppIconId.{camel(ALIASES[base_name(n)])}),' for n in legacy)
    (core / 'app_icon_catalog.dart').write_text(f'''// Generated by tools/generate_command_icons.py. Edit the source geometry there.
import 'package:flutter/material.dart';
import '../l10n/l10n_extensions.dart';

/// Semantic, locale-independent identifiers. The same command uses one asset.
enum AppIconId {{
{enum}
}}

extension AppIconDefinition on AppIconId {{
  String get assetPath => switch (this) {{
{paths}
  }};

  String label(AppLocalizations l) => switch (this) {{
{labels}
  }};
}}

/// Explicit bridge for icons supplied by existing renderer/category models.
/// New command descriptors use AppIconId directly. Unknown data is an error,
/// never a generic symbol standing in for an uncovered command.
abstract final class AppIcons {{
  static final Map<IconData, AppIconId> _material = Map.fromEntries([
{mappings}
  ]);

  static AppIconId fromMaterial(IconData? icon) {{
    final id = _material[icon];
    if (id == null) {{
      throw ArgumentError.value(icon, 'icon', 'Unregistered command icon');
    }}
    return id;
  }}
}}
''', encoding='utf-8')
    gallery = ROOT / 'docs/command-icons.html'
    gallery.parent.mkdir(exist_ok=True)
    sections = []
    for lang, arb in arbs.items():
        cards = []
        for name in names:
            samples = ''.join(f'<span class="sample" style="--size:{size}px">{svg(ICONS[name]["geometry"])}</span>' for size in (14, 16, 20, 24))
            cards.append(f'<article data-search="{html.escape(name + " " + arbs["en"][message(name)] + " " + arbs["bg"][message(name)], quote=True)}">'
                         f'<h3>{html.escape(arb[message(name)])}</h3><a href="../assets/icons/commands/{name}.svg" download="{name}.svg"><code>{name}.svg</code></a>'
                         f'<div class="light" aria-label="{arb["commandIconGalleryLight"]}">{samples}</div>'
                         f'<div class="dark" aria-label="{arb["commandIconGalleryDark"]}">{samples}</div></article>')
        sections.append(f'<section lang="{lang}"><h2>{arb["commandIconGalleryTitle"]} · {lang.upper()}</h2>'
                        f'<input aria-label="{arb["commandIconGallerySearch"]}" placeholder="{arb["commandIconGallerySearch"]}" type="search">'
                        '<div class="gallery">' + ''.join(cards) + '</div></section>')
    gallery.write_text('''<!doctype html><html lang="bg"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>''' + arbs['bg']['commandIconGalleryTitle'] + '''</title><style>
*{box-sizing:border-box}body{font:15px system-ui;margin:24px;background:#f3f5f7;color:#19232e}h2{font-size:22px}h3{font-size:14px;margin:0 0 4px}section{margin-bottom:40px}input{padding:10px;width:min(420px,100%);margin-bottom:18px;border:1px solid #aab4bf;border-radius:6px}.gallery{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:12px}article{border:1px solid #cdd4dc;border-radius:8px;background:white;padding:12px;break-inside:avoid}code{font-size:11px;color:#536273}.light,.dark{display:flex;align-items:center;justify-content:space-around;min-height:52px;margin-top:10px;border-radius:4px}.light{background:#fff;color:#19232e;border:1px solid #e0e5eb}.dark{background:#181c24;color:#f1f4f8}.sample{width:32px;height:32px;display:flex;align-items:center;justify-content:center}.sample svg{width:var(--size);height:var(--size)}@media print{input{display:none}article{border-color:#aaa}.dark{background:white;color:black}}
</style><main>''' + ''.join(sections) + '''</main><script>
document.querySelectorAll('section').forEach(section=>section.querySelector('input').addEventListener('input',event=>{const value=event.target.value.toLocaleLowerCase();section.querySelectorAll('article').forEach(card=>card.hidden=!card.dataset.search.toLocaleLowerCase().includes(value));}));
</script></html>\n''', encoding='utf-8')
    print(f'Generated {len(names)} original SVGs, {len(legacy)} explicit aliases, catalogue and BG/EN gallery.')


if __name__ == '__main__':
    generate()
