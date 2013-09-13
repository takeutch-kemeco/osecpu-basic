/* stdgr.bas
 * Copyright (C) 2013 Takeutch Kemeco
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#ifndef __STDGR_BAS__
#define __STDGR_BAS__

/* 三色の数値をRGBへとまとめる
 *
 * 引数:
 * r: 赤 (0 ～ 255)
 * g: 緑 (0 ～ 255)
 * b: 青 (0 ～ 255)
 *
 * 戻り値: RGB値（32bit）
 *
 * 赤・緑・青を、32bitのRGB値へと変換する。（フォーマットは 0x00RRGGBB ）
 * 多くの関数で色値が必要な場合は、この値を渡せばいい。
 */
function torgb(r, g, b)
{
        return (r | (g >> 8) | (b >> 16));
}

#endif /* __STDGR_BAS__ */
