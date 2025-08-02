# L4D2-HoongDou-Project
L4D2 HoongDou's Server Scripting and some Plugins

红豆服的插件包以及一些源码。

## Using sourcemod v 1.10 & v 1.9.0 compile ,maybe update @ 1.12
使用sourcemod v1.10和 v1.9.0 进行编译 ，近期更新的插件会使用较新的1.12 -git7165进行重构和更新。

## Folder Scripting is my Compiler Environment
Scripting是编译环境，有兴趣的可以自行下载。

## Plugin list:

1. tank_and_witch_ifier
按Zonemod的写法，每关生成一个Tank和一个witch。

2. connect_infomation
使用旧版的geoipcity数据库，显示连接城市和断开连接的原因。一个低配版本的cannounce.
（新版在主目录下-connectinfo，通过一个免费的Api进行查询，该Api每天允许500次免费调用次数）
3. healup
离开安全门时幸存者回满血

4. survivor_mvp
药役用，特性是关闭终点安全门时生还有人在门内的情况下会再次显示mvp信息。（在zlc表现中仍然有bug）

5. HitStatisticsLikeDianDian
被控信息统计，仿点点写的。

6. modsettings
药役/药抗用，开/关MOD设定，开启/关闭MOD后需要重载地图才能生效，使用时请确保该插件为最后一个加载的插件，否则容易出BUG。

7. rygive
测试用插件，比较快捷的刷物资/药品/特感，目前从1.0版本(2017)升级并重构，解决了一部分语法错误。

8. tankdata
坦克对幸存者造成的伤害统计和幸存者对坦克造成的伤害统计，以聊天框的界面输出。

9. Advanced_Uncommon_Control
合并了 Silvers和dcx2的插件，主要实现了 爆头秒杀 防爆丧尸、Gimmy Gibs 和 Fallen Survivors，以及对防爆丧尸的正面穿透。