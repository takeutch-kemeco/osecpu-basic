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

#include "matrix.bas"

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
function __torgb(r, g, b)
{
        return (r | (g >> 8) | (b >> 16));
}

/* 3項から最大値インデックスを探す
 *
 * 引数:
 * a,b,c: 最大値を探したい3項
 *
 * 戻り値: [0] = a, [1] = b, [2] = c と考えた場合のインデックス値
 */
function __search_max3(a, b, c)
{
        if ((a >= b) & (a >= c))
                return 0;
        else if ((b >= c) & (b >= a))
                return 1;
        else
                return 2;
}

/* 2項から最小値インデックスを探す
 *
 * 引数:
 * a,b: 最小値を探したい2項
 *
 * 戻り値: [0] = a, [1] = b と考えた場合のインデックス値
 */
function __search_min2(a, b)
{
        if (a <= b)
                return 0;
        else
                return 1;
}

/* 3項から最大値、中間値、最小値のインデックスを探す命令を出力する
 * あらかじめ fixL, fixR, fixS に値をセットしておくこと。演算結果はfixAへ出力される。
 *
 * 引数:
 * a,b,c: 最大値、中間値、最小値を探したい3項
 *
 * 戻り値: [0] = a, [1] = b, [2] = c と考えた場合のインデックス値を、2bit毎に配列した値
 *        0-1bit = min, 2-3bit = mid, 4-5bit = max
 */
function __search_minmidmax3(a, b, c)
{
        dim max = __search_max3(a, b, c);
        if (max == 0) {
                dim min = __search_min2(b, c);
                if (min == 0)
                        return (0 << 4) | (2 << 2) | (1 << 0);

                return (0 << 4) | (1 << 2) | (2 << 0);
        } else if (max == 1) {
                dim min = __search_min2(a, c);
                if (min == 0)
                        return (1 << 4) | (2 << 2) | (0 << 0);

                return (1 << 4) | (0 << 2) | (2 << 0);
        } else {
                dim min = __search_min2(a, b);
                if (min == 0)
                        return (2 << 4) | (1 << 2) | (0 << 0);

                return (2 << 4) | (0 << 2) | (1 << 0);
        }
}

/* 頂点 a,b,c (ay = by) によるスキャンライン単位での三角形塗りつぶし
 *
 * 引数:
 * mode: 描画モード
 * x0, y0, x1, y1, x2, y2: 塗りつぶしたい三角形の頂点座標
 * color: RGB色値
 * type:
 *      0 : min -> max （正）方向
 *      1 : max -> min （負）方向
 *
 * 戻り値: 無し
 *
 * ope_comparison: これは +方向 or -方向用 によって処理を変えるため
 */
function __filltri_sl_common(mode, x0, y0, x1, y1, x2, y2, color, type)
{
        dim ac_dx = (x2 - x0) / (y2 - y0);
        dim bc_dx = (x2 - x1) / (y2 - y1);

        if (type == 0) {
                while (y0 <= y2) {
                        __drawline(mode, x0, y0, x1, y0, color);
                        __drawline(mode, x0, y0+1, x1, y0+1, color);

                        y0 = y0 + 1;
                        x0 = x0 + ac_dx;
                        x1 = x1 + bc_dx;
                }
        } else {
                while (y0 >= y2) {
                        __drawline(mode, x0, y0, x1, y0, color);
                        __drawline(mode, x0, y0+1, x1, y0+1, color);

                        y0 = y0 - 1;
                        x0 = x0 - ac_dx;
                        x1 = x1 - bc_dx;
                }
        }
}

/* 頂点 a,b,c による三角形塗りつぶしする命令を出力する。
 *
 * 引数:
 * mode: 描画モード
 * x0, y0, x1, y1, x2, y2: 塗りつぶしたい三角形の頂点座標
 * color: RGB色値
 *
 * 戻り値: 無し
 */
function __filltri(mode, x0, y0, x1, y1, x2, y2, color)
{
        /* min, mid, max を調べて min,max 間の中点座標単位 mx, my を得て、
         * それら中点座標を用いて、2つのスキャンライン三角形に分割し、それぞれを描画する。
         */

        /* 頂点をmin,mid,max順に再配置
         */

        dim order = __search_minmidmax3(y0, y1, y2);

        dim max_x, max_y;
        dim mid_x, mid_y;
        dim min_x, min_y;

        /* 012 */
        if (order == 6) {
                max_x = x0; max_y = y0;
                mid_x = x1; mid_y = y1;
                min_x = x2; min_y = y2;

        /* 021 */
        } else if (order == 9) {
                max_x = x0; max_y = y0;
                mid_x = x2; mid_y = y2;
                min_x = x1; min_y = y1;

        /* 120 */
        } else if (order == 24) {
                max_x = x1; max_y = y1;
                mid_x = x2; mid_y = y2;
                min_x = x0; min_y = y0;

        /* 102 */
        } else if (order == 18) {
                max_x = x1; max_y = y1;
                mid_x = x0; mid_y = y0;
                min_x = x2; min_y = y2;

        /* 201 */
        } else if (order == 33) {
                max_x = x2; max_y = y2;
                mid_x = x0; mid_y = y0;
                min_x = x1; min_y = y1;

        /* 210 */
        } else if (order == 36) {
                max_x = x2; max_y = y2;
                mid_x = x1; mid_y = y1;
                min_x = x0; min_y = y0;
        } else {
                return;
        }

        /* min,max間を midYで分割した場合のsx,syを得る
         */
        dim sx = min_x + (((max_x - min_x) / (max_y - min_y)) * (mid_y - min_y));
        dim sy = mid_y;

        /* 三角形 s,mid,min の描画 */
        __filltri_sl_common(mode, sx, sy, mid_x, mid_y, min_x, min_y, color, 1);

        /* color = color >> 1; */

        /* 三角形 s,mid,max の描画 */
        __filltri_sl_common(mode, sx, sy, mid_x, mid_y, max_x, max_y, color, 0);
}

#endif /* __STDGR_BAS__ */
