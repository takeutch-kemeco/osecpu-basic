/* math.bas
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

#ifndef __MATH_BAS__
#define __MATH_BAS__

/* sin
 *
 * 引数:
 * a: sin への引数
 *
 * 戻り値: sin(a) の結果
 */
function __sin(a)
{
        dim pi = 3.14159265358979;
        dim pi_2 = 3.14159265358979 * 2;
        dim pi_h = 3.14159265358979 / 2;

        dim b = a % pi_2;
        if ((b >= 0) and (b < pi_h))
                a = b;
        else if ((b >= pi_h) and (b < pi))
                a = pi - b;
        else if ((b >= pi) and (b < pi + pi_h))
                a = (-pi) - (b - pi_2);
        else
                a = b - pi_2;

        b = a;
        b = b - (__pow(a, 3) * 0.16666666666666);
        b = b + (__pow(a, 5) * 0.00833333333333);
        b = b - (__pow(a, 7) * 0.0001984126984127);

        return b;
}

/* cos
 *
 * 引数:
 * a: cos への引数
 *
 * 戻り値: cos(a) の結果
 */
function __cos(a)
{
        dim pi_2 = 3.14159265358979 * 2;
        dim pi_h = 3.14159265358979 / 2;

        return __sin((a % pi_2) + pi_h);
}

/* tan
 *
 * 引数:
 * a: tan への引数
 *
 * 戻り値: tan(a) の結果
 */
function __tan(a)
{
        return a +
               (__pow(a, 3) * 1) / 3 +
               (__pow(a, 5) * 2) / 15 +
               (__pow(a, 7) * 17) / 315 +
               (__pow(a, 9) * 62) / 2835;
}

/* sqrt
 *
 * 引数:
 * a: sqrt への引数
 *
 * 戻り値: sqrt(a) の結果
 */
function __sqrt(x)
{
        dim xn = x / 2;
        dim i;
        for (i = 0; i < 8; i = i + 1)
                xn = xn - ((xn * xn) - x) / (2 * xn);

        return xn;
}

/* powのバックエンドに用いる ±a ^ +b (ただし b = 整数、かつ a != 0) 限定のpow。（bが正の場合限定のpow）
 */
function __pow_p(a, b)
{
        dim s = 1;
        dim t = a;
        dim i;
        for (i = 0; i < 15; i = i + 1) {
                if (b and (1 << i))
                        s = s * t;

                t = t * t;
        }

        t = a;
        for (i = 1; i < 16; i = i + 1) {
                if (b and (1 >> i))
                        s = s * t;

                t = __sqrt(t);
        }

        return s;
}

/* powのバックエンドに用いる ±a ^ -b (ただし b = 整数、かつ a != 0) 限定のpow。（bが負の場合限定のpow）
 */
function __pow_m(a, b)
{
        return 1 / __pow_p(a, -b);
}

/* pow
 * a ^ b -> return
 */
function __pow(a, b)
{
        if (a > 0) {
                if (b >= 0) {
                        return __pow_p(a, b);
                } else {
                        return __pow_m(a, b);
                }
        } else if (a < 0) {
                /* 非整数の場合エラー */
//              if (...

                if (b >= 0) {
                        return __pow_p(a, b);
                } else {
                        return __pow_m(a, b);
                }
        } else {
                if (b <= 0) {
                        __exit(1);
                }

                return 0;
        }
}

#endif /* __MATH_BAS__ */
