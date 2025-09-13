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

10. 1shot
某练习模式的回归，这次完全重构，可以通过调整特感在地面/空中受到的伤害倍率实现更极限的练习，也适应了特感血量上限(那些hunter 奇奇怪怪的血量上限也一并适配了)。

11. confogl_autoloader
confogl系列的自动加载模式的插件，已重构。
使用方法：1、启动项添加  confogl_autoloader_config zonemod(或者换成喜欢的模式)；
2、设置了自动加载的，可以在server.cfg中添加  confogl_autoloader_config zonemod(或者换成喜欢的模式)；
增加了可以在加载配置之前预执行某些配置文件，可通过启动项 +confogl_autoloader_execcfg xxxx.cfg进行。

12. advanced_spawnspecials
一个不太成熟的刷特，基于导演系统的（指刷特数量经常被导演系统拒绝）。目前兼容了readyup。

13. readyup_extend
对readyup插件做了药役化的准备，使其在不更改原有readyup的情况下具有以下能力：
1、生还者人满并全部ready后会自动触发forcestart开始本局。
2、每个生还都可以在队伍未满时输入!fs进行强开游戏。输入者有临时的管理员权限，待服务器键入强开指令后会撤回该权限，防止管理员权限滥化。

14. smoker-anim-fix
Smoker拉人动作丢失的修复。目前只在versus模式下测试过。其他模式待测。

15. MeleeInTheSafeRoom
开局生成近战，只更新了语法。

16. adminmenu_mission_list
适配fdxx和钵钵鸡大佬的换图插件，是在管理员菜单直接操作，可读取翻译后的地图/关卡名，方便分类换图。