
## HTTP req/s at 1 clients (median [min-max] of 3 runs)

| app | room_show | messages_page | sidebar | search | post_message | avatar | static_css | up |
|---|---|---|---|---|---|---|---|---|
| falcon-fixes | 110 [109-110] | 187 [184-190] | 216 [216-217] | 186 [180-186] | 123 [122-124] | 19230 [19176-19241] | 23055 [22998-23708] | 1597 [1583-1621] |
| sinatra | 385 [384-386] | 598 [587-601] | 1104 [1095-1107] | 766 [761-776] | 516 [513-518] | 3004 [2992-3023] | 5697 [5683-5749] | 5038 [4997-5047] |

## HTTP req/s at 16 clients (median [min-max] of 3 runs)

| app | room_show | messages_page | sidebar | search | post_message | avatar | static_css | up |
|---|---|---|---|---|---|---|---|---|
| falcon-fixes | 338 [334-354] | 567 [566-580] | 615 [610-615] | 548 [539-557] | 242 [242-247] | 62625 [62557-63697] | 84370 [83565-85555] | 4110 [4070-4146] |
| sinatra | 1316 [1315-1322] | 2108 [2100-2113] | 4003 [3989-4004] | 2821 [2817-2844] | 1529 [1506-1533] | 10612 [10518-10686] | 21318 [21170-21435] | 18614 [18568-18626] |

## HTTP req/s at 64 clients (median [min-max] of 3 runs)

| app | room_show | messages_page | sidebar | search | post_message | avatar | static_css | up |
|---|---|---|---|---|---|---|---|---|
| falcon-fixes | 333 [333-345] | 578 [564-579] | 614 [595-615] | 548 [532-552] | 247 [242-250] | 51749 [51459-51780] | 73060 [71949-73492] | 4181 [4128-4302] |
| sinatra | 1312 [1307-1316] | 2096 [2088-2096] | 3972 [3961-3979] | 2811 [2792-2829] | 1488 [1453-1495] | 10566 [10554-10600] | 21246 [21180-21328] | 18608 [18436-18691] |

## Cable fan-out (median of runs)

| app | clients | ready | delivery p50 ms | p99 ms | delivered msg/s | complete |
|---|---|---|---|---|---|---|
| falcon-fixes | 100 | 100 | 19.6 | 54.0 | 89.4 | 4023/4023 |
| falcon-fixes | 500 | 500 | 46.2 | 101.1 | 25.7 | 1194/1194 |
| falcon-fixes | 1000 | 1000 | 81.8 | 180.0 | 12.8 | 649/649 |
| sinatra | 100 | 100 | 5.0 | 8.2 | 461.5 | 20790/20790 |
| sinatra | 500 | 500 | 10.9 | 31.6 | 162.9 | 7123/7123 |
| sinatra | 1000 | 1000 | 19.5 | 36.7 | 88.9 | 4080/4080 |

## Upload, memory, cold start (median)

| app | upload ms | idle MB | peak MB | cold start ms |
|---|---|---|---|---|
| falcon-fixes | 67.4 | 630 | 1863 | 5849 |
| sinatra | 42.5 | 154 | 2805 | 1138 |
