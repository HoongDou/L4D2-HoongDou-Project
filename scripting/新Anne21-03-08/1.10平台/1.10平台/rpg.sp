#pragma semicolon 1
#pragma tabsize 0
#include <sourcemod>
#include <adminmenu>
#include <sdktools_functions>
#include <sdktools>
#include <sdkhooks>
#include <admin.inc>
#include <l4d2lib>
#include <left4dhooks>
#include <colors>
#include <float>
#include <AnneRPG> 
#include <adt_array> 
#include "modules/server.sp"
#include "modules/gift.sp"
//常规设定
#define TEAM_SPECTATORS 1		//Team数值
#define TEAM_SURVIVORS 2		//Team数值
#define TEAM_INFECTED 3		//Team数值
#define CLASS_TANK		8   //Tank的class值
#define IsValidClient(%1)		(1 <= %1 <= MaxClients && IsClientInGame(%1))    //定义客户端是否在游戏中
#define IsValidAliveClient(%1)	(1 <= %1 <= MaxClients && IsClientInGame(%1) && IsPlayerAlive(%1))   //定义客户端是否在游戏中并且扮演
//购物主界面
#define ARMS 			1	//武器
#define	MELEE			2	//近战
#define PROPS 			3	//道具
//购买武器
#define	PISTOL			10	//手枪
#define	MAGNUM			11	//马格南手枪
#define	SMG				12	//冲锋枪
#define	SMGSILENCED		13	//消声冲锋枪
#define PUMPSHOTGUN1	15	//老式单发霰弹
#define PUMPSHOTGUN2	16	//新式单发霰弹
#define	AUTOSHOTGUN1	17	//老式连发霰弹
#define	AUTOSHOTGUN2	18	//新式连发霰弹
#define HUNTING1		19	//猎枪
#define	HUNTING2		20	//G3SG1狙击枪
#define M16				23  //M16
#define	AK47			24   //AK47
#define	SCAR			25	//三连发
#define	AWP			26	//AWP
#define	grenadelauncher			27	//榴弹
#define	sniperscout			28	//AWP
#define	m60			29	//m60
//补给物品
#define	ADRENALINE		50	//肾上腺素
#define	PAINPILLS		51	//药丸
#define	FIRSTAIDKIT		52	//医疗包
#define	GASCAN		53	//油桶
/*** 玩家基本属性资料 ***/
/** 技能上限 **/
/* 攻击/击杀/召唤尸消失被击杀次数计算 */
new ZombiesKillCount[MAXPLAYERS+1];
new BuyCount[MAXPLAYERS+1];
new Handle:ZombiesKillCountTimer[MAXPLAYERS+1]			= {	INVALID_HANDLE, ...};
new Handle:CheckExpTimer[MAXPLAYERS+1]					= {	INVALID_HANDLE, ...};
new Handle:hCvarMotdTitle;
new Handle:hCvarMotdUrl;
new Handle:hCvarIPUrl;
public void OnPluginStart()
{
	RegisterCmds();
	HookEvents();
	SR_PluginStart();
	GF_PluginStart();
}
RegisterCmds()
{
	RegConsoleCmd("sm_rpg",			Menu_RPG);
	RegConsoleCmd("sm_buy",			Menu_RPG);
	RegConsoleCmd("sm_lv",			Menu_STATUS);
	RegConsoleCmd("sm_pw",			Menu_STATUS);
	RegConsoleCmd("sm_away", AFKTurnClientToSpe);
	RegConsoleCmd("sm_s", AFKTurnClientToSpe);
	RegConsoleCmd("say",		Command_Say);
	RegConsoleCmd("say_team",		Command_SayTeam);
	RegConsoleCmd("sm_rank", ShowMOTD);
	RegConsoleCmd("sm_ip", ShowIP);
	RegAdminCmd("sm_restartmap", RestartMap, ADMFLAG_ROOT, "restarts map");
}
HookEvents()
{
	AddCommandListener(Command_Setinfo, "jointeam");
	AddCommandListener(Command_Setinfo1, "chooseteam");
	AddNormalSoundHook(NormalSHook:OnNormalSound);
	AddAmbientSoundHook(AmbientSHook:OnAmbientSound);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_team", Event_PlayerTeam);	
	HookEvent("witch_killed", WitchKilled_Event);
	HookEvent("finale_win", ResetSurvivors);
	HookEvent("map_transition", ResetSurvivors);
	HookEvent("round_start", event_RoundStart);
	hCvarMotdTitle = CreateConVar("sm_cfgmotd_title", "AnneHappy");
    hCvarMotdUrl = CreateConVar("sm_cfgmotd_url", "http://47.115.132.92/test.php");
	hCvarIPUrl = CreateConVar("sm_cfgip_url", "http://47.115.132.92/serverip.php");
	
}
public Action RestartMap(client,args)
{
	CrashMap();
}
public event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	for (new client = 1; client <= MaxClients; client++) 
	{
		BuyCount[client] = 0;
		if (!IsSurvivor(client)) 
		{
			player_data[client][INFECTED] = 0;
		}
		else if(player_data[client][LELVEL] != 0)
		{
			Update_DATA(client,false);
		}
	}
	CreateTimer( 3.0, Timer_DelayedOnRoundStart, _, TIMER_FLAG_NO_MAPCHANGE );
}
public Action:ShowMOTD(client, args) 
{
    decl String:title[64], String:url[192];
    GetConVarString(hCvarMotdTitle, title, sizeof(title));
    GetConVarString(hCvarMotdUrl, url, sizeof(url));
    ShowMOTDPanel(client, title, url, MOTDPANEL_TYPE_URL);
}
public Action:ShowIP(client, args) 
{
    decl String:title[64], String:url[192];
    GetConVarString(hCvarMotdTitle, title, sizeof(title));
    GetConVarString(hCvarIPUrl, url, sizeof(url));
	if(player_data[client][LELVEL] > 60)
	{
		ShowMOTDPanel(client, title, url, MOTDPANEL_TYPE_URL);
	}
	else
	{
		PrintToChat(client, "\x04[公告]\x01:\x05尚未踏入天玄境，不允许查看!");
	}
}
public Action:Timer_DelayedOnRoundStart(Handle:timer) 
{
	SetConVarString(FindConVar("mp_gamemode"), "coop");
	if(HasHumanOnServer())
	{
		MYSQL_INITIP();
		Update_DATAIP();
	}
	char sMapConfig[128];
	GetCurrentMap(sMapConfig, sizeof(sMapConfig));
    Format(sMapConfig, sizeof(sMapConfig), "cfg/sourcemod/map_cvars/%s.cfg", sMapConfig);
    if (FileExists(sMapConfig, true))
    {
        strcopy(sMapConfig, sizeof(sMapConfig), sMapConfig[4]);
        ServerCommand("exec \"%s\"", sMapConfig);
    }
}

//sql数据上传
public Action L4D2_OnEndVersusModeRound(bool countSurvivors)
{
	SetConVarString(FindConVar("mp_gamemode"), "realism");
	return Plugin_Handled;
}
//过关重置
public Action:ResetSurvivors(Handle:event, const String:name[], bool:dontBroadcast)
{
	RestoreHealth();
	ResetInventory();
}
public OnClientPutInServer(client)
{
	if(client > 0 && IsClientConnected(client) && !IsFakeClient(client))
	{
		CreateTimer(3.0, Timer_CheckDetay, client, TIMER_FLAG_NO_MAPCHANGE);
		FakeClientCommand(client, "sm_rank");
		if(player_data[client][LELVEL] < 0)
		{
			KickClient(client);
		}
	}
}
public Action:Command_Say(client, args)
{
	if (client == 0 || IsChatTrigger())
	{
		return Plugin_Continue;
	}
	decl	String:sMessage[1024];
	GetCmdArgString(sMessage, sizeof(sMessage));
	GetClientLevel(client);
	if(player_data[client][LELVEL] > 10)
    {
        CPrintToChatAll("%s {olive}: %s", NameInfo(client, colored), sMessage);
		LogToFile(logfilepath, "%s:%s", NameInfo(client, simple), sMessage);
    }
	else
    {
        CPrintToChatAll("\x04%N {olive}: %s", client, sMessage);
		LogToFile(logfilepath, "%s:%s", NameInfo(client, simple), sMessage);
    }
	 return Plugin_Handled;
}

public Action:Command_SayTeam(client, args)
{
	if (client == 0 || IsChatTrigger())
	{
		return Plugin_Continue;
	}
	decl	String:sMessage[1024];
	GetCmdArgString(sMessage, sizeof(sMessage));
	GetClientLevel(client);
	if(player_data[client][LELVEL] > 10)
    {
        CPrintToChatAll("%s {olive}: %s", NameInfo(client, colored), sMessage);
		LogToFile(logfilepath, "%s:%s", NameInfo(client, simple), sMessage);
    }
	else
    {
        CPrintToChatAll("\x04%N {olive}: %s", client, sMessage);
		LogToFile(logfilepath, "%s:%s", NameInfo(client, simple), sMessage);
    }
	return Plugin_Handled;
}
public Action:Event_PlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	new Client = GetEventInt(event, "userid");
	new target = GetClientOfUserId(Client);
	new team = GetEventInt(event, "team");
	new bool:disconnect = GetEventBool(event, "disconnect");
	if (IsValidPlayer(target) && !disconnect && team == 3)
	{
		if(!IsFakeClient(target))
		{
			CreateTimer(0.5, Timer_CheckDetay2, target, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	return Plugin_Continue;
}

public Action:Timer_CheckDetay(Handle:Timer, any:client)
{
	if(IsValidPlayerInTeam(client, 3))
	{
		ChangeClientTeam(client, 1); 
	}
	if(player_data[client][LELVEL] < 0)
	{
		KickClient(client);
	}
}
public Action:Timer_CheckDetay2(Handle:Timer, any:client)
{
	ChangeClientTeam(client, 1); 
}
static Initialization(i)
{
	KillAllClientSkillTimer(i);
}
KillAllClientSkillTimer(Client)
{
	/* 停止击杀丧尸Timer */
	if(ZombiesKillCountTimer[Client] != INVALID_HANDLE)
	{
		ZombiesKillCount[Client] = 0;
		KillTimer(ZombiesKillCountTimer[Client]);
		ZombiesKillCountTimer[Client] = INVALID_HANDLE;
	}
}
//监听控制台jointeam 3指令并阻止
public Action:Command_Setinfo(client, const String:command[], args)
{
    decl String:arg[32];
    GetCmdArg(1, arg, sizeof(arg));
    if (!StrEqual(arg, "survivor") || IsSuivivorTeamFull())
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
} 
public Action:Command_Setinfo1(client, const String:command[], args)
{
    return Plugin_Handled;
} 
//闲置指令 若点了内鬼技能使用该指令将技能将减1级
public Action:AFKTurnClientToSpe(client, args) 
{
	if(!IsPinned(client))
	CreateTimer(2.5, Timer_CheckAway, client, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Handled;
}
public Action:Timer_CheckAway(Handle:Timer, any:client)
{
	ChangeClientTeam(client, 1); 
}
//出门根据技能效果给予近战物品
public Action:L4D_OnFirstSurvivorLeftSafeArea() 
{
	SetConVarString(FindConVar("mp_gamemode"), "coop");
	CreateTimer(0.5, Timer_AutoGive, _, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Stop;
}
public Action:Timer_AutoGive(Handle:timer) 
{
	for (new client = 1; client <= MaxClients; client++) 
	{
		if (IsSurvivor(client)) 
		{
			BypassAndExecuteCommand(client, "give","pain_pills"); 
			BypassAndExecuteCommand(client, "give","health"); 
			SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);		
			SetEntProp(client, Prop_Send, "m_currentReviveCount", 0);
			SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", false);
			if (player_data[client][MELEE] == 1 ) 
			{ 
				BypassAndExecuteCommand(client, "give", "machete");
			}
			if (player_data[client][MELEE] == 2) 
			{ 
				BypassAndExecuteCommand(client, "give","fireaxe"); 
			}
			if (player_data[client][MELEE] == 3) 
			{ 
				BypassAndExecuteCommand(client, "give","knife"); 
			}
			if (player_data[client][MELEE] == 4) 
			{ 
				BypassAndExecuteCommand(client, "give","katana"); 
			}
			if (player_data[client][MELEE] == 5) 
			{ 
				BypassAndExecuteCommand(client, "give","pistol_magnum"); 
			}
			if(IsFakeClient(client))
			{
				for (new i = 0; i < 1; i++) 
				{ 
					DeleteInventoryItem(client, i);		
				}
				BypassAndExecuteCommand(client, "give","smg_silenced");
				BypassAndExecuteCommand(client, "give","pistol_magnum");
			}
		}
	}
}
//玩家加入游戏
public OnClientConnected(client)
{
	new humans = GetHumanCount();
	if(humans > 4)
	{
		PrintToChatAll("[检测到未知错误.即将重启地图]");
		ServerCommand("sm_restartmap");
	}
	if(!IsFakeClient(client))
	{
		CheckExpTimer[client] = CreateTimer(1.0, PlayerLevelAndMPUp, client, TIMER_REPEAT);
		Initialization(client);
		PrintToChatAll("\x04 %N \x05正在爬进服务器",client);
	}
}
// 玩家离开游戏 
public OnClientDisconnect(client)
{
	SR_ClientDisconnect(client);
	if(!IsFakeClient(client) && IsClientInGame(client))
	{
		GetClientLevel(client);
		if(player_data[client][LELVEL] > 10)
		{
			CPrintToChatAll("%s{olive} 离开了游戏", NameInfo(client, colored));
		}
		else
		{
			PrintToChatAll("\x04 %N \x05 离开了游戏", client);
		}
		Initialization(client);
		if(player_data[client][LELVEL] > 0)
		{
			Update_DATA(client,true);
		}
	}
}
//玩家进入服务器后进行数据库查询
public OnClientPostAdminCheck(client)
{
	decl String:id[32];
	if (IsClientConnected(client))
	GetClientAuthId(client,AuthId_Steam2,id,sizeof(id));
	if ((StrEqual(id, "BOT")))	 return ;
	else
	{
		MYSQL_INIT(client,id);
	}
}
//RPG经验到达升级时进行升级
public Action:PlayerLevelAndMPUp(Handle:timer, any:target)
{
	if(IsClientInGame(target))
	{
		if(player_data[target][EXPERIENCE] >= 100 * (player_data[target][LELVEL]+1))
		{
			player_data[target][EXPERIENCE] -= 100 *(player_data[target][LELVEL]+1);
			player_data[target][LELVEL] += 1;
		}
	}
	return Plugin_Continue;
}
//秒妹回实血
public WitchKilled_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client) && !IsPlayerIncap(client))
	{
		new targetHealth = GetSurvivorPermHealth(client) + 15;
		if(targetHealth > 100)
		{
			targetHealth = 100;
		}
		SetSurvivorPermHealth(client, targetHealth);
	}
}
// 各种经验值和技能回血效果
public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if(IsValidClient(victim))
	{
		if(GetClientTeam(victim) == TEAM_INFECTED)
		{
			if(IsSurvivor(attacker))	//玩家幸存者杀死特殊感染者
			{
				
					if(!IsFakeClient(attacker))
					{
						//new targetHealth = GetSurvivorPermHealth(attacker);
						player_data[attacker][EXPERIENCE] += 10;
						//player_data[attacker][MONEY] += 10;
						if(player_data[attacker][BLOOD] > 0)
						{
							targetHealth += 1;
						}
						if(player_data[attacker][BLOOD] > 1)
						{
							targetHealth += 1;
						}
						if(targetHealth > 100)
						{
							targetHealth = 100;
						}
						if(!IsPlayerIncap(attacker))
						{
							SetSurvivorPermHealth(attacker, targetHealth);
						}
					}
					else
					{
						new targetHealth = GetSurvivorPermHealth(attacker);
						targetHealth += 2;
						if(targetHealth > 100)
						{
							targetHealth = 100;
						}
						if(!IsPlayerIncap(attacker))
						{
							SetSurvivorPermHealth(attacker, targetHealth);
						}
					}
				}
			}
	}
	else if (!IsValidClient(victim))
	{
		if(IsValidClient(attacker))
		{
			if(GetClientTeam(attacker) == TEAM_SURVIVORS && !IsFakeClient(attacker))	//玩家幸存者杀死普通感染者
			{
				if(ZombiesKillCountTimer[attacker] == INVALID_HANDLE)	ZombiesKillCountTimer[attacker] = CreateTimer(5.0, ZombiesKillCountFunction, attacker);
				ZombiesKillCount[attacker] ++;
			}
		}
	}
	return Plugin_Continue;
}

//击杀小丧尸计数和经验
public Action:ZombiesKillCountFunction(Handle:timer, any:attacker)
{
	KillTimer(timer);
	ZombiesKillCountTimer[attacker] = INVALID_HANDLE;
	if (IsValidClient(attacker))
	{
		if (ZombiesKillCount[attacker] > 0)
		{
			player_data[attacker][EXPERIENCE] += ZombiesKillCount[attacker] * 5;
			//player_data[attacker][MONEY] += ZombiesKillCount[attacker] * 1;
		}
		ZombiesKillCount[attacker]=0;
	}
}
/******************************************************
*	United RPG选单
*******************************************************/
public Action:AddB(Client, args) 
{
	if(player_data[Client][LELVEL] >= 1)
	{
		player_data[Client][LELVEL] -= 1;
		player_data[Client][MONEY] += player_data[Client][LELVEL];
		player_data[Client][MONEY] -= 20;
	}
	MenuFunc_tongji(Client);
}
public Action:AddLV(Client, args) 
{
	if(player_data[Client][MONEY] > player_data[Client][LELVEL])
	{
		player_data[Client][LELVEL] += 1;
		player_data[Client][MONEY] -= player_data[Client][LELVEL];
	}
	MenuFunc_tongji(Client);
}
//近战技能
public Action:AddStrength(Client, args) 
{
	if(player_data[Client][MONEY] >= 100 || player_data[Client][MELEE] > 0)
	{
		if (args < 1)
		{
			if(player_data[Client][MELEE] + 1 > 5)
			{
				return Plugin_Handled;
			}
			else
			{
				if(player_data[Client][MELEE] < 1)
				{
					player_data[Client][MONEY] -= 100;
				}
				player_data[Client][MELEE] += 1;
				return Plugin_Handled;
			}
		}
	}
	return Plugin_Handled;
}

//回血技能
public Action:AddEndurance(Client, args) 
{
	if(player_data[Client][MONEY] >= 200)
	{
		if (args < 1)
		{
			if(player_data[Client][BLOOD]  + 1 > 2)
			{
				return Plugin_Handled;
			}
			else
			{
				player_data[Client][BLOOD]  += 1;
				player_data[Client][MONEY] -= 200;
				return Plugin_Handled;
			}
		}
	}
	return Plugin_Handled;
}
stock GetInfectedCount()
{
	new index = 0;
	new i;
	for(i = 1; i <= MaxClients; i++)
	{
		if(player_data[i][INFECTED] > 0)
		{
			index++;
		}	
	}
	return index;
}
//重置技能
public Action:ResetBshu(Client, args)
{
	if(player_data[Client][MONEY] > 0)
	{
		if (args < 1)
		{
			player_data[Client][MONEY] += player_data[Client][BLOOD] * 200 ;
			if(player_data[Client][MELEE] > 0)
			{
				player_data[Client][MONEY] += 100;
			}
			player_data[Client][BLOOD] = 0;
			player_data[Client][MELEE] = 0;
			return Plugin_Handled;	
		}
	}
	return Plugin_Handled;
}

/******************************************************
*	United RPG选单
*******************************************************/
public Action:Menu_RPG(Client,args)
{
	MenuFunc_Xsbz(Client);
	return Plugin_Handled;
}
//!pw或者!lv查询服务器玩家信息
public Action:Menu_STATUS(Client,args)
{
	displaykillinfected();
	return Plugin_Handled;
}
displaykillinfected()
{
	new client;
	new players;
	new players_clients[MAXPLAYERS+1];
	for (client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client)) 
			players_clients[players++] = client;
	}
	SortCustom1D(players_clients, 10, SortByDamageDesc);
	for (new i; i <= 10; i++)
	{
		client = players_clients[i];
		if (IsValidClient(client) && !IsFakeClient(client)) 
		{
			GetClientLevel(client);
			CPrintToChatAll("%s  {green}<B数> {blue}%d", NameInfo(client, colored), player_data[client][MONEY]);
		}
	}
}

public SortByDamageDesc(elem1, elem2, const array[], Handle:hndl)
{
	if (player_data[elem1][LELVEL] > player_data[elem2][LELVEL]) return -1;
	else if (player_data[elem2][LELVEL] > player_data[elem1][LELVEL]) return 1;
	else if (elem1 > elem2) return -1;
	else if (elem2 > elem1) return 1;
	return 0;
}
/* RPG面板*/
public Action:MenuFunc_Xsbz(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();

	Format(line, sizeof(line), "AnneHappy");			
	SetPanelTitle(menu, line);
    
	Format(line, sizeof(line), "购物商店");
	DrawPanelItem(menu, line);
	
	Format(line, sizeof(line), "技能商店");
	DrawPanelItem(menu, line);
	
	Format(line, sizeof(line), "其他玩意");
	DrawPanelItem(menu, line);
	
	Format(line, sizeof(line), "关闭菜单");
	DrawPanelItem(menu, line);
	SendPanelToClient(menu, Client, MenuHandler_Xsbz, MENU_TIME_FOREVER);
}

//RPG面板执行
public MenuHandler_Xsbz(Handle:menu, MenuAction:action, Client, param)//基础菜单	
{
	if (action == MenuAction_Select) 
	{
		switch (param)
		{
			case 1: ShowMenu(Client);
			case 2: MenuFunc_AddStatus(Client);
			case 3: MenuFunc_tongji(Client);
		}
	}
}

/* 技能菜单 */
public Action:MenuFunc_AddStatus(Client)
{
	new Handle:menu = CreatePanel();
	decl String:line[256];
	Format(line, sizeof(line), "B数: %d", player_data[Client][MONEY]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "尽梨了 (%d/%d) 总计需100点B数,", player_data[Client][MELEE], 5);
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "1砍刀 2斧头 3小刀 4武士刀 5马格南");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "莓良心 (%d/%d) 每级需200点B数", player_data[Client][BLOOD], 2);
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "杀特回血:1级回1血 2级回2血");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "重置技能  免费(返还技能B数)");
	DrawPanelItem(menu, line);
	DrawPanelItem(menu, "Exit", ITEMDRAW_DISABLED);
	SendPanelToClient(menu, Client, MenuHandler_AddStatus, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}

//技能加点
public MenuHandler_AddStatus(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		switch(param)
			{
				case 1:	AddStrength(Client, 0);
				//case 2:	AddEndurance(Client, 0);
				case 2:	ResetBshu(Client, 0);
			}
		MenuFunc_AddStatus(Client);
	}
}

//个人信息
public Action:MenuFunc_tongji(Client)
{ 
	new Handle:menu = CreatePanel();
	decl String:line[256];
	
	Format(line, sizeof(line), "%N\n等级Lv.%d \n经验值:%d/%d \nB数:%d", Client, player_data[Client][LELVEL], player_data[Client][EXPERIENCE],100 *(player_data[Client][LELVEL]+1),player_data[Client][MONEY]);
	SetPanelTitle(menu, line);	
	Format(line, sizeof(line), "等级转B数");  
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "等级下降一级，增加（等级 - 20）B数");
	DrawPanelText(menu, line);
	Format(line, sizeof(line), "B数转等级");  
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "等级增加一级，扣除（等级 + 1）B数");
	DrawPanelText(menu, line);
	DrawPanelItem(menu, "离开", ITEMDRAW_DISABLED);
    
	SendPanelToClient(menu, Client, MenuHandler_tongji, MENU_TIME_FOREVER);
	CloseHandle(menu);
	return Plugin_Handled;
}

//刷新个人信息
public MenuHandler_tongji(Handle:menu, MenuAction:action, Client, param)
{
	if (action == MenuAction_Select)
	{
		switch (param)
		{
			case 1:	AddB(Client, 0);
			case 2:	AddLV(Client, 0);
		}
	}
}
/*-----------------------------------------方法区--------------------------------------------------*/
//这是主界面

public CharMenu(Handle:menu, MenuAction:action, param1, param2) 
{
	switch (action) 
	{
		case MenuAction_Select: 
		{
			decl String:item[8];
			GetMenuItem(menu, param2, item, sizeof(item));
			
			switch(StringToInt(item)) 
			{
				case ARMS:		{	ShowTypeMenu(param1,ARMS);	}
				case PROPS:		{	ShowTypeMenu(param1,PROPS);	}
			}
		}
		case MenuAction_Cancel:
		{
			
		}
		case MenuAction_End: 
		{
			CloseHandle(menu);
		}
	}
}

public Action:ShowMenu(Client)
{	
	decl String:sMenuEntry[8];
	new Handle:menu = CreateMenu(CharMenu);
	SetMenuTitle(menu, "B数:%i",player_data[Client][MONEY]);
	IntToString(ARMS, sMenuEntry, sizeof(sMenuEntry));
	AddMenuItem(menu, sMenuEntry, "购买枪械");
	IntToString(PROPS, sMenuEntry, sizeof(sMenuEntry));
	AddMenuItem(menu, sMenuEntry, "购买补给");
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, Client, MENU_TIME_FOREVER);
}

//这是购买武器

public CharArmsMenu(Handle:menu, MenuAction:action, param1, param2) 
{
	switch (action) 
	{
		case MenuAction_Select: 
		{
			decl String:item[8];
			GetMenuItem(menu, param2, item, sizeof(item));
			
			switch(StringToInt(item)) 
			{
				case PISTOL:
				{
					if(IsSurvivor(param1))
					{
						BypassAndExecuteCommand(param1, "give", "ammo");
					}
				}
				case MAGNUM:	
				{	
					if(player_data[param1][MONEY] < 1)
					{ 
						PrintToChat(param1,"\x03你自己心里没有点B数吗?");
					} 
					else
					{
						BypassAndExecuteCommand(param1, "give", "pistol_magnum");
						player_data[param1][MONEY] -= 5;
						PrintToChatAll("\x04%N\x03花了5点B数购买了马格南手枪",param1);
					}
				}
				case SMG:	
				{	
					if(BuyCount[param1] == 0)
					{
						BypassAndExecuteCommand(param1, "give", "smg");
						BuyCount[param1] += 1;
					}
					else
					{
						BypassAndExecuteCommand(param1, "give", "smg");
						player_data[param1][MONEY] -= 5;
						PrintToChatAll("\x04%N\x03花了5点B数购买了UZI冲锋枪",param1);
					}
				}
				case SMGSILENCED:	
				{	
					if(BuyCount[param1] == 0)
					{
						BypassAndExecuteCommand(param1, "give", "smg_silenced");
						BuyCount[param1] += 1;
					}
					else
					{
						BypassAndExecuteCommand(param1, "give", "smg_silenced");
						player_data[param1][MONEY] -= 5;
						PrintToChatAll("\x04%N\x03花了5点B数购买了SMG冲锋枪",param1);
					}
				}
				case PUMPSHOTGUN1:
				{
					if(BuyCount[param1] == 0)
					{
						BypassAndExecuteCommand(param1, "give", "pumpshotgun");
						BuyCount[param1] += 1;
					}
					else
					{
						BypassAndExecuteCommand(param1, "give", "pumpshotgun");
						player_data[param1][MONEY] -= 5;
						PrintToChatAll("\x04%N\x03花了5点B数购买了一代单发霰弹枪",param1);
					}
				}
				case PUMPSHOTGUN2:
				{
					if(IsSurvivor(param1) && BuyCount[param1] == 0)
					{
						BypassAndExecuteCommand(param1, "give", "shotgun_chrome");
						BuyCount[param1] += 1;
					}
					else if(BuyCount[param1] != 0)
					{
						BypassAndExecuteCommand(param1, "give", "shotgun_chrome");
						player_data[param1][MONEY] -= 5;
						PrintToChatAll("\x04%N\x03花了%i点B数购买了二代单发霰弹枪",param1,5);
					}
				}
				case AUTOSHOTGUN1:
				{
					if(player_data[param1][MONEY] < 10)
					{ 
						PrintToChat(param1,"\x03你自己心里没有点B数吗?");
					} 
					else
					{
						BypassAndExecuteCommand(param1, "give", "autoshotgun");
						player_data[param1][MONEY] -= 10;
						PrintToChatAll("\x04%N\x03花了10点B数购买了一代连发霰弹枪",param1);
					}
				}
				case AUTOSHOTGUN2:
				{
					if(player_data[param1][MONEY] < 10)
					{
						PrintToChat(param1,"\x03你自己心里没有点B数吗?");
					} 
					else
					{
						BypassAndExecuteCommand(param1, "give", "shotgun_spas");
						player_data[param1][MONEY] -= 10;
						PrintToChatAll("\x04%N\x03花了10点B数购买了二代连发霰弹枪",param1);
					}
				}
				case HUNTING1:
				{
					if(player_data[param1][MONEY] < 10)
					{ 
						PrintToChat(param1,"\x03你自己心里没有点B数吗?");
					} 
					else
					{
						BypassAndExecuteCommand(param1, "give", "hunting_rifle");
						player_data[param1][MONEY] -= 10;
						PrintToChatAll("\x04%N\x03花了10点B数购买了一代狙击枪",param1);
					}
				}
				case HUNTING2:
				{
					if(player_data[param1][MONEY] < 10)
					{
						PrintToChat(param1,"\x03你自己心里没有点B数吗?");
					} 
					else
					{
						BypassAndExecuteCommand(param1, "give", "sniper_military");
						player_data[param1][MONEY] -= 10;
						PrintToChatAll("\x04%N\x03花了10点B数购买了二代狙击枪",param1);
					}
				}
				
				case M16:
				{
					if(player_data[param1][MONEY] < 10)
					{ 
						PrintToChat(param1,"\x03你自己心里没有点B数吗?");
					} 
					else
					{
						BypassAndExecuteCommand(param1, "give", "rifle");
						player_data[param1][MONEY] -= 10;
						PrintToChatAll("\x04%N\x03花了10点B数购买了M16步枪",param1);
					}
				}
				case AK47:
				{
					if(player_data[param1][MONEY] < 10)
					{ 
						PrintToChat(param1,"\x03你自己心里没有点B数吗?");
					} 
					else
					{
						BypassAndExecuteCommand(param1, "give", "rifle_ak47");
						player_data[param1][MONEY] -= 10;
						PrintToChatAll("\x04%N\x03花了10点B数购买了AK47步枪",param1);
					}
				}
				case SCAR:
				{
					if(player_data[param1][MONEY] < 10)
					{ 
						PrintToChat(param1,"\x03你自己心里没有点B数吗?");
					} 
					else
					{
						BypassAndExecuteCommand(param1, "give", "rifle_desert");
						player_data[param1][MONEY] -= 10;
						PrintToChatAll("\x04%N\x03花了10点B数购买了SCAR步枪",param1);
					}
				}
				case AWP:
				{
					if(player_data[param1][MONEY] < 25)
					{
						PrintToChat(param1,"\x03你自己心里没有点B数吗?");
					} 
					else
					{
						BypassAndExecuteCommand(param1, "give", "sniper_awp");
						player_data[param1][MONEY] -= 25;
						PrintToChatAll("\x04%N\x03花了25点B数购买了AWP狙击枪",param1);
					}
				}
				case grenadelauncher:
				{
					if(player_data[param1][MONEY] < 25)
					{ 
						PrintToChat(param1,"\x03你自己心里没有点B数吗?");
					} 
					else
					{
						BypassAndExecuteCommand(param1, "give", "grenade_launcher");
						player_data[param1][MONEY] -= 25;
						PrintToChatAll("\x04%N\x03花了25点B数购买了榴弹发射器",param1);
					}
				}
				case sniperscout:
				{
					if(player_data[param1][MONEY] < 10)
					{ 
						PrintToChat(param1,"\x03你自己心里没有点B数吗?");
					} 
					else
					{
						BypassAndExecuteCommand(param1, "give", "sniper_scout");
						player_data[param1][MONEY] -= 10;
						PrintToChatAll("\x04%N\x03花了10点B数购买了鸟狙",param1);
					}
				}
				case m60:
				{
					if(player_data[param1][MONEY] < 25)
					{ 
						PrintToChat(param1,"\x03你自己心里没有点B数吗?");
					} 
					else if(IsSurvivor(param1))
					{
						BypassAndExecuteCommand(param1, "give", "rifle_m60");
						player_data[param1][MONEY] -= 25;
						PrintToChatAll("\x04%N\x03花了25点B数购买了M60",param1);
					}
				}
				case ADRENALINE:
				{
					if(player_data[param1][MONEY] < 10)
					{ 
						PrintToChat(param1,"\x03你自己心里没有点B数吗?");
					} 
					else
					{
						BypassAndExecuteCommand(param1, "give", "adrenaline");
						player_data[param1][MONEY] -= 10;
						PrintToChatAll("\x04%N\x03花了%i点B数购买了肾上腺素",param1,10);
					}
				}
				case PAINPILLS:
				{
					if(player_data[param1][MONEY] < 15)
					{
						PrintToChat(param1,"\x03你自己心里没有点B数吗?");
					} 
					else
					{
						BypassAndExecuteCommand(param1, "give", "pain_pills");
						player_data[param1][MONEY] -= 15;
						PrintToChatAll("\x04%N\x03花了%i点B数购买了止痛药",param1,15);
					}
				}
				case FIRSTAIDKIT:
				{
					if(player_data[param1][MONEY] < 20)
					{ 
						PrintToChat(param1,"\x03你自己心里没有点B数吗?");
					} 
					else
					{
						BypassAndExecuteCommand(param1, "give", "first_aid_kit");
						player_data[param1][MONEY] -= 20;
						PrintToChatAll("\x04%N\x03花了%i点B数购买了急救包",param1,20);
					}
				}
				case GASCAN:
				{
					if(player_data[param1][MONEY] < 10)
					{
						PrintToChat(param1,"\x03你自己心里没有点B数吗?");
					} 
					else
					{
						BypassAndExecuteCommand(param1, "give", "gascan");
						player_data[param1][MONEY] -= 10;
						PrintToChatAll("\x04%N\x03花了%i点B数购买了油桶",param1,10);
					}
				}
			}
		}
		case MenuAction_Cancel:
		{
			
		}
		case MenuAction_End: 
		
		{
			CloseHandle(menu);
		}
	}
}

public ShowTypeMenu(Client,type)
{	
	decl String:sMenuEntry[8];
	new String:money[64];
	new Handle:menu = CreateMenu(CharArmsMenu);
	switch(type)
	{
		case ARMS:
		{
			SetMenuTitle(menu, "B数:%i",player_data[Client][MONEY]);
			
			Format(money,sizeof(money),"子弹堆(%d点B数)",0);
			IntToString(PISTOL, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
					
			Format(money,sizeof(money),"马格南手枪(%d点B数)",5);
			IntToString(MAGNUM, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
			
			if(BuyCount[Client] == 0)
			{
				Format(money,sizeof(money),"UZI冲锋枪(%d点B数)",0);
				IntToString(SMG, sMenuEntry, sizeof(sMenuEntry));
				AddMenuItem(menu, sMenuEntry, money);
				
				Format(money,sizeof(money),"SMG冲锋枪(%d点B数)",0);
				IntToString(SMGSILENCED, sMenuEntry, sizeof(sMenuEntry));
				AddMenuItem(menu, sMenuEntry, money);
			
				Format(money,sizeof(money),"一代单发霰弹枪(%d点B数)",0);
				IntToString(PUMPSHOTGUN1, sMenuEntry, sizeof(sMenuEntry));
				AddMenuItem(menu, sMenuEntry, money);
					
				Format(money,sizeof(money),"二代单发霰弹枪(%d点B数)",0);
				IntToString(PUMPSHOTGUN2, sMenuEntry, sizeof(sMenuEntry));
				AddMenuItem(menu, sMenuEntry, money);
				
				
			}
			else
			{
				Format(money,sizeof(money),"UZI冲锋枪(%d点B数)",5);
				IntToString(SMG, sMenuEntry, sizeof(sMenuEntry));
				AddMenuItem(menu, sMenuEntry, money);
				
				Format(money,sizeof(money),"SMG冲锋枪(%d点B数)",5);
				IntToString(SMGSILENCED, sMenuEntry, sizeof(sMenuEntry));
				AddMenuItem(menu, sMenuEntry, money);
					
				Format(money,sizeof(money),"一代单发霰弹枪(%d点B数)",5);
				IntToString(PUMPSHOTGUN1, sMenuEntry, sizeof(sMenuEntry));
				AddMenuItem(menu, sMenuEntry, money);
					
				Format(money,sizeof(money),"二代单发霰弹枪(%d点B数)",5);
				IntToString(PUMPSHOTGUN2, sMenuEntry, sizeof(sMenuEntry));
				AddMenuItem(menu, sMenuEntry, money);
			}
					
			Format(money,sizeof(money),"一代连发霰弹枪(%d点B数)",10);
			IntToString(AUTOSHOTGUN1, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
					
			Format(money,sizeof(money),"二代连发霰弹枪(%d点B数)",10);
			IntToString(AUTOSHOTGUN2, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
					
			Format(money,sizeof(money),"一代狙击枪(%d点B数)",10);
			IntToString(HUNTING1, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
					
			Format(money,sizeof(money),"二代狙击枪(%d点B数)",10);
			IntToString(HUNTING2, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
			
			Format(money,sizeof(money),"M16步枪(%d点B数)",10);
			IntToString(M16, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
			
			Format(money,sizeof(money),"AK47步枪(%d点B数)",10);
			IntToString(AK47, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
			
			Format(money,sizeof(money),"SCAR步枪(%d点B数)",10);
			IntToString(SCAR, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
			
			Format(money,sizeof(money),"AWP狙击枪(%d点B数)",25);
			IntToString(AWP, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
			
			Format(money,sizeof(money),"榴弹发射器(%d点B数)",25);
			IntToString(grenadelauncher, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
			
			Format(money,sizeof(money),"鸟狙(%d点B数)",10);
			IntToString(sniperscout, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
			
			Format(money,sizeof(money),"M60(%d点B数)",25);
			IntToString(m60, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
		}
		
		case PROPS:
		{
			SetMenuTitle(menu, "B数:%i",player_data[Client][MONEY]);
			
			Format(money,sizeof(money),"肾上腺素(%d点B数)",10);
			IntToString(ADRENALINE, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
			
			Format(money,sizeof(money),"止痛药(%d点B数)",15);
			IntToString(PAINPILLS, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
			
			Format(money,sizeof(money),"医疗包(%d点B数)",20);
			IntToString(FIRSTAIDKIT, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
			
			Format(money,sizeof(money),"油桶(%d点B数)",10);
			IntToString(GASCAN, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
		}
	}
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, Client, MENU_TIME_FOREVER);
}
public Action:OnNormalSound(int clients[64], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags)
{
	return (StrContains(sample, "firewerks", true) > -1) ? Plugin_Stop : Plugin_Continue;
}
public Action:OnAmbientSound(char sample[PLATFORM_MAX_PATH], int &entity, float &volume, int &level, int &pitch, float pos[3], int &flags, float &delay)
{
	return (StrContains(sample, "firewerks", true) > -1) ? Plugin_Stop : Plugin_Continue;
}