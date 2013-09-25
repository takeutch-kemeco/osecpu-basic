/* stdoscp.bas
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

#ifndef __STDOSCP_BAS__
#define __STDOSCP_BAS__

/* 変数の値（数値のみ）を画面へ印字する
 *
 * 引数:
 * num: 画面へ表示したい変数
 *
 * 戻り値: 無し
 */
function __print(num)
{
        asm("fixL" = num);

        /* 符号を保存しておき、正に変換 */
        asm("if (fixL < 0) {fixS = 1; fixL = -fixL;} else {fixS = 0;}");

        /* 負の場合は-符号を表示する */
        asm("if (fixS == 1) {junkApi_putConstString('-');}");

        /* 整数側の表示 */
        asm("fixLx = fixL >> 16;");
        asm("junkApi_putStringDec('\1', fixLx, 6, 1);");

        /* 小数点を表示 */
        asm("junkApi_putConstString('.');");

        /* 小数側の表示 */
        asm("fixR = 0;");
        asm("if ((fixL & 0x00008000) != 0) {fixR += 5000;}");
        asm("if ((fixL & 0x00004000) != 0) {fixR += 2500;}");
        asm("if ((fixL & 0x00002000) != 0) {fixR += 1250;}");
        asm("if ((fixL & 0x00001000) != 0) {fixR += 625;}");
        asm("if ((fixL & 0x00000800) != 0) {fixR += 312;}");
        asm("if ((fixL & 0x00000400) != 0) {fixR += 156;}");
        asm("if ((fixL & 0x00000200) != 0) {fixR += 78;}");
        asm("if ((fixL & 0x00000100) != 0) {fixR += 39;}");
        asm("if ((fixL & 0x00000080) != 0) {fixR += 19;}");
        asm("if ((fixL & 0x00000040) != 0) {fixR += 10;}");
        asm("if ((fixL & 0x00000020) != 0) {fixR += 5;}");
        asm("if ((fixL & 0x00000010) != 0) {fixR += 2;}");
        asm("if ((fixL & 0x00000008) != 0) {fixR += 1;}");
        asm("if ((fixL & 0x00000004) != 0) {fixR += 1;}");

        asm("junkApi_putStringDec('\1', fixR, 4, 6);");

        /* 自動改行はさせない （最後にスペースを表示するのみ） */
        asm("junkApi_putConstString(' ');");
}

/* ヒープメモリー上の任意アドレスから、１ワード読み込む
 * アドレスを定数で直接指定したい場合は、 >> 16 した値を渡すこと。
 *
 * 引数:
 * address: 読み込みたいヒープメモリーのアドレス。（アドレスはワード単位）
 *          例1:
 *              123 ワード目のアドレスから、変数 a へ1ワード読み込みたい場合:
 *              a = peek(123 >> 16);
 *
 *          例2:
 *              変数 a のアドレスから、10ワード先のアドレスから、変数 b へ1ワード読み込みたい場合:
 *              b = peek(&a + (10 >> 16));
 *
 * 戻り値: 読み込んだ値。（1ワード）
 */
function __peek(address)
{
        float ret;

        asm("fixL" = address);
        asm("PALMEM0(fixA, T_SINT32, mem_ptr, fixL);");

        asm(ret = "fixA");
        return ret;
}

/* ヒープメモリー上の任意アドレスへ、１ワード書き込む
 * アドレスを定数で直接指定したい場合は、 >> 16 した値を渡すこと。
 *
 * 引数:
 * address: 読み込みたいヒープメモリーのアドレス。（アドレスはワード単位）
 * value: 書き込む値
 *          例1:
 *              123 ワード目のアドレスへ、変数 a の値を1ワード書き込みたい場合:
 *              poke(123 >> 16, a);
 *
 *          例2:
 *              変数 a のアドレスから、10ワード先のアドレスへ、変数 b の値を1ワード書き込みたい場合:
 *              poke(&a + (10 >> 16), b);
 *
 * 戻り値: 無し
 */
function __poke(address, value)
{
        asm("fixL" = address);
        asm("fixR" = value);
        asm("PASMEM0(fixR, T_SINT32, mem_ptr, fixL);");
}

/* 描画領域を初期設定して開く
 *
 * 引数:
 * width: 描画領域の横幅
 * height: 描画領域の縦幅
 *
 * 戻り値: 無し  　
 */
function __openwin(width, height)
{
        asm("fixL" = width);
        asm("fixR" = height);
        asm("fixL >>= 16;");
        asm("fixR >>= 16;");
        asm("junkApi_openWin(fixL, fixR);");
}

/* 描画領域をフレームバッファーへフラッシュする
 *
 * 引数:
 * width: フラッシュする描画領域の横幅 / 8
 * height: フラッシュする描画領域の縦幅 / 16
 * x: フラッシュする描画領域の左上点の x 座標
 * y: フラッシュする描画領域の左上点の y 座標
 *
 * 戻り値: 無し
 */
function __flushwin(width, height, x, y)
{
        asm("fixL" = width);
        asm("fixR" = height);
        asm("fixLx" = x);
        asm("fixRx" = y);

        asm("fixL >>= 16;");
        asm("fixR >>= 16;");
        asm("fixLx >>= 16;");
        asm("fixRx >>= 16;");

        asm("junkApi_flushWin(fixL, fixR, fixLx, fixRx);");
}

/* 指定ミリ秒間だけスリープする
 *
 * 引数:
 * mode: (1 << 0): フレームバッファーのフラッシュを行わない。
 *       (1 << 1): キー入力があるまでスリープしつづける。
 * msec: スリープ時間をミリ秒単位で指定する
 *
 * 戻り値: 無し
 */
function __sleep(mode, msec)
{
        asm("fixL" = mode);
        asm("fixR" = msec);
        asm("fixL >>= 16;");
        asm("fixR >>= 16;");
        asm("junkApi_sleep(fixL, fixR);");
}

/* アプリケーションの終了
 *
 * 引数:
 * retval: この値をアプリケーションの戻り値とする
 *
 * 戻り値: 無し
 */
function __exit(retval)
{
        asm("fixL" = retval);
        asm("fixL >>= 16;");
        asm("jnukApi_exit(fixL);");
}

/* 矩形範囲の塗りつぶし
 *
 * 引数:
 * mode: 0: 通常の描画
 *       1: OR描画
 *       2: XOR描画
 *       3: AND描画
 *       (1 << 2): 8色モード（color を 0~2bit=B, 3~5bit=G, 6~9bit=R として扱う）
 *       (1 << 4): 画面外への描画をエラーとしない
 * width: 矩形の横幅
 * height: 矩形の縦幅
 * x: 矩形の左上点の x 座標
 * y: 矩形の左上点の y 座標
 * color: 通常は、塗りつぶしの色を 0x00RRGGBB の形式で指定。
 *        mode が (1 << 4) の場合は各色3bitによる形式で指定。
 *
 * 戻り値: 無し
 */
function __fillrect(mode, width, height, x, y, color)
{
        asm("fixT" = mode);
        asm("fixL" = width);
        asm("fixR" = height);
        asm("fixLx" = x);
        asm("fixRx" = y);
        asm("fixS" = color);

        asm("fixT >>= 16;");
        asm("fixL >>= 16;");
        asm("fixR >>= 16;");
        asm("fixLx >>= 16;");
        asm("fixRx >>= 16;");

        asm("junkApi_fillRect(fixT, fixL, fixR, fixLx, fixRx, fixS);");
}

/* 矩形を描画
 *
 * 引数:
 * mode: 0: 通常の描画
 *       1: OR描画
 *       2: XOR描画
 *       3: AND描画
 *       (1 << 2): 8色モード（color を 0~2bit=B, 3~5bit=G, 6~9bit=R として扱う）
 *       (1 << 4): 画面外への描画をエラーとしない
 * width: 矩形の横幅
 * height: 矩形の縦幅
 * x: 矩形の左上点の x 座標
 * y: 矩形の左上点の y 座標
 * color: 通常は、塗りつぶしの色を 0x00RRGGBB の形式で指定。
 *        mode が (1 << 4) の場合は各色3bitによる形式で指定。
 *
 * 戻り値: 無し
 */
function __drawrect(mode, width, height, x, y, color)
{
        asm("fixT" = mode);
        asm("fixL" = width);
        asm("fixR" = height);
        asm("fixLx" = x);
        asm("fixRx" = y);
        asm("fixS" = color);

        asm("fixT >>= 16;");
        asm("fixL >>= 16;");
        asm("fixR >>= 16;");
        asm("fixLx >>= 16;");
        asm("fixRx >>= 16;");

        asm("junkApi_drawRect(fixT, fixL, fixR, fixLx, fixRx, fixS);");
}

/* 点を描画
 *
 * 引数:
 * mode: 0: 通常の描画
 *       1: OR描画
 *       2: XOR描画
 *       3: AND描画
 *       (1 << 2): 8色モード（color を 0~2bit=B, 3~5bit=G, 6~9bit=R として扱う）
 *       (1 << 4): 画面外への描画をエラーとしない
 * x: 矩形の左上点の x 座標
 * y: 矩形の左上点の y 座標
 * color: 通常は、塗りつぶしの色を 0x00RRGGBB の形式で指定。
 *        mode が (1 << 4) の場合は各色3bitによる形式で指定。
 *
 * 戻り値: 無し
 */
function __drawpoint(mode, x, y, color)
{
        asm("fixT" = mode);
        asm("fixLx" = x);
        asm("fixRx" = y);
        asm("fixS" = color);

        asm("fixT >>= 16;");
        asm("fixLx >>= 16;");
        asm("fixRx >>= 16;");

        asm("junkApi_drawPoint(fixT, fixLx, fixRx, fixS);");
}

/* 楕円の塗りつぶし
 *
 * 引数:
 * mode: 0: 通常の描画
 *       1: OR描画
 *       2: XOR描画
 *       3: AND描画
 *       (1 << 2): 8色モード（color を 0~2bit=B, 3~5bit=G, 6~9bit=R として扱う）
 *       (1 << 4): 画面外への描画をエラーとしない
 * width: 矩形の横幅
 * height: 矩形の縦幅
 * x: 矩形の左上点の x 座標
 * y: 矩形の左上点の y 座標
 * color: 通常は、塗りつぶしの色を 0x00RRGGBB の形式で指定。
 *        mode が (1 << 4) の場合は各色3bitによる形式で指定。
 *
 * 戻り値: 無し
 */
function __filloval(mode, width, height, x, y, color)
{
        asm("fixT" = mode);
        asm("fixL" = width);
        asm("fixR" = height);
        asm("fixLx" = x);
        asm("fixRx" = y);
        asm("fixS" = color);

        asm("fixT >>= 16;");
        asm("fixL >>= 16;");
        asm("fixR >>= 16;");
        asm("fixLx >>= 16;");
        asm("fixRx >>= 16;");

        asm("junkApi_fillOval(fixT, fixL, fixR, fixLx, fixRx, fixS);");
}

/* 楕円を描画
 *
 * 引数:
 * mode: 0: 通常の描画
 *       1: OR描画
 *       2: XOR描画
 *       3: AND描画
 *       (1 << 2): 8色モード（color を 0~2bit=B, 3~5bit=G, 6~9bit=R として扱う）
 *       (1 << 4): 画面外への描画をエラーとしない
 * width: 矩形の横幅
 * height: 矩形の縦幅
 * x: 矩形の左上点の x 座標
 * y: 矩形の左上点の y 座標
 * color: 通常は、塗りつぶしの色を 0x00RRGGBB の形式で指定。
 *        mode が (1 << 4) の場合は各色3bitによる形式で指定。
 *
 * 戻り値: 無し
 */
function __drawoval(mode, width, height, x, y, color)
{
        asm("fixT" = mode);
        asm("fixL" = width);
        asm("fixR" = height);
        asm("fixLx" = x);
        asm("fixRx" = y);
        asm("fixS" = color);

        asm("fixT >>= 16;");
        asm("fixL >>= 16;");
        asm("fixR >>= 16;");
        asm("fixLx >>= 16;");
        asm("fixRx >>= 16;");

        asm("junkApi_drawOval(fixT, fixL, fixR, fixLx, fixRx, fixS);");
}

/* 線分を描画
 *
 * 引数:
 * mode: 0: 通常の描画
 *       1: OR描画
 *       2: XOR描画
 *       3: AND描画
 *       (1 << 2): 8色モード（color を 0~2bit=B, 3~5bit=G, 6~9bit=R として扱う）
 *       (1 << 4): 画面外への描画をエラーとしない
 * x0: 線分の始点の x 座標
 * y0: 線分の始点の y 座標
 * x1: 線分の終点の x 座標
 * y1: 線分の終点の y 座標
 * color: 通常は、塗りつぶしの色を 0x00RRGGBB の形式で指定。
 *        mode が (1 << 4) の場合は各色3bitによる形式で指定。
 *
 * 戻り値: 無し
 */
function __drawline(mode, x0, y0, x1, y1, color)
{
        asm("fixT" = mode);
        asm("fixL" = x0);
        asm("fixR" = y0);
        asm("fixLx" = x1);
        asm("fixRx" = y1);
        asm("fixS" = color);

        asm("fixT >>= 16;");
        asm("fixL >>= 16;");
        asm("fixR >>= 16;");
        asm("fixLx >>= 16;");
        asm("fixRx >>= 16;");

        asm("junkApi_drawLine(fixT, fixL, fixR, fixLx, fixRx, fixS);");
}

/* キーボード入力を得る
 *
 * 引数:
 * mode: 0: キーコードを得る。
 *       1: キーボードバッファーをクリアーせずにキーコードを得る。
 *
 * 戻り値: キーコード
 */
function __inkey(mode)
{
        float ret;

        asm("fixT" = mode);
        asm("fixT >>= 16;");

        asm("junkApi_inkey(fixA, fixT);");

        asm(ret = "fixA");
        return ret;
}

/* 乱数を得る
 *
 * 引数:
 * max: 乱数の最大値
 *
 * 戻り値: キーコード
 */
function __rand(max)
{
        float ret;

        asm("fixL" = max);
        asm("fixL >>= 16;");

        asm("junkApi_rand(fixA, fixL);");

        asm("fixA <<= 16;");
        asm(ret = "fixA");
        return ret;
}

#endif /* __STDOSCP_BAS__ */
