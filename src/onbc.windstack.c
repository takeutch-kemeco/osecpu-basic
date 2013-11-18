/* onbc.windstack.c
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

#include <stdint.h>
#include "onbc.print.h"

#define WINDSTACK_POOL_LEN 0x10000
static int32_t windstack_pool[WINDSTACK_POOL_LEN];

static int32_t cur_windstack_head = 0;

static int32_t cur_wind_offset = 0;

void push_windstack(const int32_t size)
{
        cur_windstack_head++;
        if (cur_windstack_head >= WINDSTACK_POOL_LEN)
                yyerror("system err: push_windstack()");

        cur_wind_offset += size;
        windstack_pool[cur_windstack_head] = cur_wind_offset;
}

int32_t pop_windstack(void)
{
        const int32_t size = windstack_pool[cur_windstack_head];

        cur_windstack_head--;
        if (cur_windstack_head < 0)
                yyerror("system err: pop_windstack()");

        cur_wind_offset = windstack_pool[cur_windstack_head];

        return size;
}

void nest_windstack(void)
{
        cur_wind_offset = 0;
}

void init_windstack(void)
{
        cur_wind_offset = 0;
        cur_windstack_head = 0;
}
