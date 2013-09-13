/* matrix.bas
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

#ifndef __MATRIX_BAS__
#define __MATRIX_BAS__

/* 3x3単位行列
 * 単位行列 -> m0
 */
function idn_matrix3(m0)
{
        dim ma[3,3];
        m0@ma[0,0] = 1; m0@ma[0,1] = 0; m0@ma[0,2] = 0;
        m0@ma[1,0] = 0; m0@ma[1,1] = 1; m0@ma[1,2] = 0;
        m0@ma[2,0] = 0; m0@ma[2,1] = 0; m0@ma[2,2] = 1;
}

/* 3x3行列のスカラー倍
 * scale * m0 -> m0
 */
function scale_matrix3(m0, scale)
{
        dim ma[3,3];

        dim j;
        for (j = 0; j < 3; j = j + 1) {
                dim i;
                for (i = 0; i < 3; i = i + 1) {
                        m0@ma[j,i] = scale * m0@ma[j,i];
                }
        }
}

/* 3次元ベクトルのスカラー倍
 * scale * v0 -> v0
 */
function scale_vector3(v0, scale)
{
        dim va[3];

        dim i;
        for (i = 0; i < 3; i = i + 1)
                v0@va[i] = scale * v0@va[i];
}

/* 3次元ベクトルの加算
 * v1 + v2 -> v0
 */
function add_vector3(v0, v1, v2)
{
        dim va[3];

        dim i;
        for (i = 0; i < 3; i = i + 1)
                v0@va[i] = v1@va[i] + v2@va[i];
}

/* 3次元ベクトルの減算
 * v1 - v2 -> v0
 */
function sub_vector3(v0, v1, v2)
{
        dim va[3];

        dim i;
        for (i = 0; i < 3; i = i + 1)
                v0@va[i] = v1@va[i] - v2@va[i];
}

/* 3x3行列の乗算
 * m1 * m2 -> m0
 */
function mul_matrix3(m0, m1, m2)
{
        dim ma[3,3];

        dim j;
        for (j = 0; j < 3; j = j + 1) {
                dim i;
                for (i = 0; i < 3; i = i + 1) {
                        m0@ma[j,i] = m1@ma[j,0] * m2@ma[0,i] +
                                     m1@ma[j,1] * m2@ma[1,i] +
                                     m1@ma[j,2] * m2@ma[2,i];
                }
        }
}

/* 3x3行列と3次元ベクトルの乗算
 * m0 * v1 -> v0
 */
function mul_m3v3(v0, m0, v1)
{
        dim ma[3,3];
        dim va[3];

        dim j;
        for (j = 0; j < 3; j = j + 1) {
                v0@va[j] = m0@ma[j,0] * v1@va[0] +
                           m0@ma[j,1] * v1@va[1] +
                           m0@ma[j,2] * v1@va[2];
        }
}

/* 3次元ベクトルと3x3行列の乗算
 * m0 * v1 -> v0
 */
function mul_v3m3(v0, m0, v1)
{
        dim ma[3,3];
        dim va[3];

        dim i;
        for (i = 0; i < 3; i = i + 1) {
                v0@va[i] = m0@ma[0,i] * v1@va[0] +
                           m0@ma[1,i] * v1@va[1] +
                           m0@ma[2,i] * v1@va[2];
        }
}

/* (x,y,z)ベクトルから3x3回転行列を得る。
 * mz * my * mx -> m
 */
function rot_matrix3(m, v)
{
        dim mx[3,3], my[3,3], mz[3,3], mt[3,3];
        dim va[3];
        rot_x_matrix3(&mx, v@va[0]);
        rot_y_matrix3(&my, v@va[1]);
        rot_z_matrix3(&mz, v@va[2]);

        mul_matrix3(&mt, &mz, &my);
        mul_matrix3(m, &mt, &mx);
}

/* x軸回りの回転行列を得る
 */
function rot_x_matrix3(m, r)
{
        dim st = __sin(r);
        dim ct = __cos(r);
        dim a[3,3];
        idn_matrix3(m);
        m@a[1,1] = ct;
        m@a[1,2] = -st;
        m@a[2,1] = st;
        m@a[2,2] = ct;
}

/* y軸回りの回転行列を得る
 */
function rot_y_matrix3(m, r)
{
        dim st = __sin(r);
        dim ct = __cos(r);
        dim a[3,3];
        idn_matrix3(m);
        m@a[0,0] = ct;
        m@a[0,2] = st;
        m@a[2,0] = -st;
        m@a[2,2] = ct;
}

/* z軸回りの回転行列を得る
 */
function rot_z_matrix3(m, r)
{
        dim st = __sin(r);
        dim ct = __cos(r);
        dim a[3,3];
        idn_matrix3(m);
        m@a[0,0] = ct;
        m@a[0,1] = -st;
        m@a[1,0] = st;
        m@a[1,1] = ct;
}

/* 3x3行列の内容を印字
 */
function print_matrix3(m)
{
        dim ma[3,3];

        dim j;
        for (j = 0; j < 3; j = j + 1) {
                dim i;
                for (i = 0; i < 3; i = i + 1) {
                        __print(m@ma[j,i]);
                }
        }
}

/* 3次元ベクトルの内積
 * v1 * v2 -> return
 */
function inner_product_vector3(v1, v2)
{
        dim va[3];
        dim tmp = 0;

        dim i;
        for (i = 0; i < 3; i = i + 1)
                tmp = tmp + (v1@va[i] * v2@va[i]);

        return tmp;
}

/* 3次元ベクトルのクロス積
 * v1 . v2 -> v0
 */
function cross_product_vector3(v0, v1, v2)
{
        dim va[3];

        v0@va[0] = v1@va[1] * v2@va[2] - v1@va[2] * v2@va[1];
        v0@va[1] = v1@va[2] * v2@va[0] - v1@va[0] * v2@va[2];
        v0@va[2] = v1@va[0] * v2@va[1] - v1@va[1] * v2@va[0];
}

/* 3x3行列のコピー
 * m1 -> m0
 */
function copy_matrix3(m0, m1)
{
        dim ma[3,3];

        dim j;
        for (j = 0; j < 3; j = j + 1) {
                dim i;
                for (i = 0; i < 3; i = i + 1) {
                        m0@ma[j,i] = m1@ma[j,i];
                }
        }
}

/* 3x3行列の全ての要素に任意のスカラー値をセットする
 * acalar -> m0
 */
function set_scalar_matrix3(m0, scalar)
{
        dim ma[3,3];

        dim j;
        for (j = 0; j < 3; j = j + 1) {
                dim i;
                for (i = 0; i < 3; i = i + 1) {
                        m0@ma[j,i] = scalar;
                }
        }
}

/* 3x3行列の転置行列を得る
 */
function transpose_matrix3(m0)
{
        dim ma[3,3];

        dim j;
        for (j = 0; j < 3; j = j + 1) {
                dim i;
                for (i = j; i < 3; i = i + 1) {
                        dim tmp = m0@ma[j,i];
                        m0@ma[j,i] = m0@ma[i,j];
                        m0@ma[i,j] = tmp;
                }
        }
}

#endif /* __MATRIX_BAS__ */
