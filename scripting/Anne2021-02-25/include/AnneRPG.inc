#define colored	1
#define simple	2
new String:text1[512][MAXPLAYERS+1];


#include <smlib>
enum data
{
	LV,
	EXP,
	Str,
	Endurance,
	Intelligence,
	CASH
};
int player_data[MAXPLAYERS+1][data];

new String:InitIP[]="INSERT INTO `serverip`(`AnneIP` , `AnneNAME`, `AnneTICK`) VALUES (?,?,0)"; 
new String:SelectIP[]="select * from serverip l where l.AnneIP=?";   //查询数据
new String:Update_serverip[]="update serverip l set l.AnneNAME=?,l.AnneTICK=?  where l.AnneIP=?"; //这个是过图或者重启关卡的时候更新一次，不更新游戏时间
// connect--->初始化(读取MYSQL数据，为空则添加)---离开游戏(更新玩家数据UPDATE)
new String:Init[]="INSERT INTO `l4d3`(`steam_id`, `steam_name`, `LV_DATA`, `EXP_DATA`,`Str_DATA`,`Endurance_DATA`,`Intelligence_DATA`, `CASH_DATA`,`STATUS`) VALUES (?,?,0,0,0,0,0,0,1)"; 
new String:Select[]="select * from l4d3 l where l.steam_id=?";   //查询数据
new String:Update[]="update l4d3 l set l.LV_DATA=?,l.EXP_DATA=?,l.Str_DATA=?,l.Endurance_DATA=?,l.CASH_DATA=?,l.steam_name=? where l.steam_id=?"; //这个是过图或者重启关卡的时候更新一次，不更新游戏时间
new String:Update_Disconnect[]="update l4d3 l set l.LV_DATA=?,l.EXP_DATA=?,l.Str_DATA=?,l.Endurance_DATA=?,l.CASH_DATA=? where l.steam_id=?";//这个是离开游戏，然后更新一下所有数据以及游戏时间
String:NameInfo(Client, mode)
{
	decl String:NameInfoString[192];
	if(IsClientInGame(Client) && !IsFakeClient(Client))
	{
		if(mode == colored)
		{
			if(StrEqual("NO",text1[Client],false) == true || StrEqual("",text1[Client],false) == true)
			{
                    if(GetClientTeam(Client) == 1)	Format(NameInfoString, sizeof(NameInfoString), "{blue}%N{default}", Client);
				else if(GetClientTeam(Client) == 2)	Format(NameInfoString, sizeof(NameInfoString), "{blue}%N{default}", Client);
				else if(GetClientTeam(Client) == 3)	Format(NameInfoString, sizeof(NameInfoString), "{blue}%N{default}", Client);
			} else if (StrEqual("NO",text1[Client],false) == false || StrEqual("",text1[Client],false) == false){
				if(GetClientTeam(Client) == 1)	Format(NameInfoString, sizeof(NameInfoString), "{green}<%s>{blue}%N{default}", text1[Client], Client);
				else if(GetClientTeam(Client) == 2)	Format(NameInfoString, sizeof(NameInfoString), "{green}<%s>{blue}%N{default}", text1[Client], Client);
				else if(GetClientTeam(Client) == 3)	Format(NameInfoString, sizeof(NameInfoString), "{green}<%s>{red}%N{default}", text1[Client], Client);
				else	Format(NameInfoString, sizeof(NameInfoString), "{green}<%s>{red}%N{default}", text1[Client], Client);
			}
		}
		else if(mode == simple) Format(NameInfoString, sizeof(NameInfoString), "<%s>%N", text1[Client], Client);
	}
	return NameInfoString;
}
bool Update_DATA(client,bool:IsDisconnect=false) 
{
	decl String:id[40];
	new String:error[256];
	new String:NAMES[256];
	GetClientName(client,NAMES,sizeof(NAMES));
	GetClientAuthId(client,AuthId_Steam2,id,sizeof(id));
	//if ((StrEqual(id, "BOT"))) return false;
	new Database:db = SQL_DefConnect(error, sizeof(error));
	if (db == null) {
		PrintToServer("【严重错误】:无法连接到MySQL数据库，错误信息：%s", error);
		CPrintToChatAll("{red}【严重错误】:无法连接到MySQL数据库，错误信息：%s", error);
		return false;
	}
	if(!SQL_FastQuery(db, "SET NAMES 'utf8mb4'"))
	{
		if(SQL_GetError(db,error,sizeof(error)))
			CPrintToChatAll("{red}【严重错误】:无法更改为UTF-8编码，错误信息：%s", error);
		else
			CPrintToChatAll("{red}【严重错误】:无法更改为UTF-8编码，错误信息：未知");
	}	
	DBStatement hAddQuery;
	if(IsDisconnect){
		if ((hAddQuery = SQL_PrepareQuery(db, Update_Disconnect, error, sizeof(error))) == null)
		{
			PrintToServer("SQL_PrepareQuery出现错误");
			//delete db;
			return false;
		}
	}else{
		if ((hAddQuery = SQL_PrepareQuery(db, Update, error, sizeof(error))) == null)
		{
			PrintToServer("SQL_PrepareQuery出现错误");
			//delete db;
			return false;
		}
	}
	//下面是参数绑定
	//行数sizeof(args)/sizeof(args[0])
	//SQL_BindParamInt
	//SQL_BindParamString(hAddQuery,0,NAMES,true);
	SQL_BindParamInt(hAddQuery,0,player_data[client][LV]);
	SQL_BindParamInt(hAddQuery,1,player_data[client][EXP]);
	SQL_BindParamInt(hAddQuery,2,player_data[client][Str]);
	SQL_BindParamInt(hAddQuery,3,player_data[client][Endurance]);
	//SQL_BindParamInt(hAddQuery,5,player_data[client][Intelligence]);
	if(IsDisconnect)
	{
		SQL_BindParamInt(hAddQuery,4,player_data[client][CASH]);
		SQL_BindParamString(hAddQuery,5,id,true);
	}
	else
	{
		SQL_BindParamInt(hAddQuery,4,player_data[client][CASH]);
		SQL_BindParamString(hAddQuery,5,NAMES,true);
		SQL_BindParamString(hAddQuery,6,id,true);
	}
	if (!SQL_Execute(hAddQuery))
	{
		PrintToServer("SQL_Execute出现错误");
		/*
		if(SQL_GetError(db,error,sizeof(error)))
			//CPrintToChatAll("{red}【严重错误】:无法提交信息，错误信息：%s", error);
		else
			//CPrintToChatAll("{red}【严重错误】:无法提交信息，错误信息：未知");	
		*/
	}
	db.Close();
	return true; 
}
public bool MYSQL_INIT(client,String:id[])
{
//全插件只有这个地方是查询
	new String:error[256];
	new String:NAMES[256];
	ArrayList array=CreateArray(40,1);
	//if(GetClientTime(client)>0.0) return true; //已经在游戏则不用查询了
	new Database:db = SQL_DefConnect(error, sizeof(error));
	if (db == null) {
		PrintToServer("【严重错误】:无法连接到MySQL数据库，错误信息：%s", error);
		CPrintToChatAll("{red}【严重错误】:无法连接到MySQL数据库，错误信息：%s", error);
		return false;
	}
	DBStatement hAddQuery;
	if ((hAddQuery = SQL_PrepareQuery(db, Select, error, sizeof(error))) == null)
	{
		PrintToServer("SQL_PrepareQuery出现错误%s",error);
		CPrintToChatAll("SQL_PrepareQuery出现错误%s",error);
		delete db;
		return false;
	}
	//下面是参数绑定
	//行数sizeof(args)/sizeof(args[0])
	SQL_BindParamString(hAddQuery,0,id,true);
	if (!SQL_Execute(hAddQuery))
	{
		PrintToServer("SQL_Execute出现错误");
	}
	if(!SQL_FetchRow(hAddQuery))
	{
		CPrintToChat(client,"{red}[注意]:您初次登录本服务器，即将为您初始化数据");
		CloseHandle(hAddQuery);
		db.Close();
		player_data[client][LV]=0;
		player_data[client][EXP]=0;
		player_data[client][Str]=0;
		player_data[client][Endurance]=0;
		player_data[client][Intelligence]=0;
		player_data[client][CASH]=0;
		GetClientName(client,NAMES,sizeof(NAMES));
		SetArrayString(array,0,id);
		ResizeArray(array,GetArraySize(array)+1);
		// 每增加一条数据都要进行ResizeArray(array,GetArraySize(array)+1)操作
		SetArrayString(array,1,NAMES);
		MySQLTransaction(Init,array);		
		return true;
	}
	else
	{
	
	MySQLTransaction(Init,array);	
	player_data[client][LV]=SQL_FetchInt(hAddQuery, 2);
	player_data[client][EXP]=SQL_FetchInt(hAddQuery, 3);
	player_data[client][Str]=SQL_FetchInt(hAddQuery, 4);
	player_data[client][Endurance]=SQL_FetchInt(hAddQuery, 5);
	//player_data[client][Intelligence]=SQL_FetchInt(hAddQuery, 6);
	player_data[client][CASH]=SQL_FetchInt(hAddQuery, 7);
	}
	db.Close();
	return true;	
}

public bool MySQLTransaction(char[] query,ArrayList  array)
{
	
	new String:error[256];
	new String:buffer[256];
	new Database:db = SQL_DefConnect(error, sizeof(error));
	if (db == null) {
		PrintToServer("【严重错误】:无法连接到MySQL数据库，错误信息：%s", error);
		CPrintToChatAll("{red}【严重错误】:无法连接到MySQL数据库，错误信息：%s", error);
		return false;
	}
	if(!SQL_FastQuery(db, "SET NAMES 'utf8mb4'"))
	{
		if(SQL_GetError(db,error,sizeof(error)))
			CPrintToChatAll("{red}【严重错误】:无法更改为UTF-8编码，错误信息：%s", error);
		else
			CPrintToChatAll("{red}【严重错误】:无法更改为UTF-8编码，错误信息：未知");
	}
	
	DBStatement hAddQuery;
	if ((hAddQuery = SQL_PrepareQuery(db, query, error, sizeof(error))) == null)
	{
		PrintToServer("SQL_PrepareQuery出现错误");
		delete db;
		return false;
	}
	//下面是参数绑定
	//行数sizeof(args)/sizeof(args[0])
	for(int i=0;i<GetArraySize(array);i++)
	{
		GetArrayString(array,i,buffer,sizeof(buffer));
		SQL_BindParamString(hAddQuery,i,buffer,true);
		//PrintToServer("位置%d绑定值为%s\n",i,buffer);
	}
	if (!SQL_Execute(hAddQuery))
	{
	/*
		if(SQL_GetError(db,error,sizeof(error)))
			//CPrintToChatAll("{red}【严重错误】:无法提交信息，错误信息：%s", error);
		else
			//CPrintToChatAll("{red}【严重错误】:无法提交信息，错误信息：未知");	
*/			
	}
	db.Close();
	return true;
}

//重置生还者武器并给手枪
public ResetInventory() 
{
	for (new client = 1; client <= MaxClients; client++) 
	{
		player_data[client][Intelligence] = 0;
		if (IsSurvivor(client)) 
		{
			for (new i = 0; i < 5; i++) 
			{ 
				DeleteInventoryItem(client, i);		
			}
			BypassAndExecuteCommand(client, "give", "pistol");
		}
	}		
}
DeleteInventoryItem(client, slot) 
{
	new item = GetPlayerWeaponSlot(client, slot);
	if (item > 0) 
	{
		RemovePlayerItem(client, item);
	}	
}
//给满生还血量
public RestoreHealth() 
{
	for (new client = 1; client <= MaxClients; client++) 
	{
		if (IsSurvivor(client)) 
		{
			player_data[client][CASH] += 5;
			BypassAndExecuteCommand(client, "give","health");
			SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);		
			SetEntProp(client, Prop_Send, "m_currentReviveCount", 0);
			SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", false);
		}
	}
}
//判断是否挂边
stock bool:IsPlayerLedge(client)
{
	if (GetEntProp(client, Prop_Send, "m_isHangingFromLedge") || GetEntProp(client, Prop_Send, "m_isFallingFromLedge"))
	{return true;} else {return false;}
}
//服务器重启
public void CrashServer()
{
    SetCommandFlags("crash", GetCommandFlags("crash")&~FCVAR_CHEAT);
    ServerCommand("crash");
}
public void CrashMap()
{
    decl String:mapname[64];
    GetCurrentMap(mapname, sizeof(mapname));
	ServerCommand("changelevel %s", mapname);
}
//获取生还者数量
stock GetHumanCount()
{
	new humans = 0;
	new i;
	for(i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2)
		{
			humans++;
		}
	}
	return humans;
}
bool: HasHumanOnServer()
{
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			return true;
		}
	}
	return false;
}
//判断是否为AI特感
//给物品函数
stock BypassAndExecuteCommand(client, String: strCommand[], String: strParam1[])
{
	new flags = GetCommandFlags(strCommand);
	SetCommandFlags(strCommand, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", strCommand, strParam1);
	SetCommandFlags(strCommand, flags);
}
//判断生还是否已经满人
/*
bool:IsSuivivorTeamFull() 
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && IsFakeClient(i))
		{
			return false;
		}
	}
	return true;
}
*/
//判断是否为生还者
stock bool:IsSurvivor(client) 
{
	if(IsClientInGame(client) && GetClientTeam(client) == 2) 
	{
		return true;
	} 
	else 
	{
		return false;
	}
}
/*
//判断是否为玩家再队伍里
bool:IsValidPlayerInTeam(client,team)
{
	if(IsValidPlayer(client))
	{
		if(GetClientTeam(client)==team)
		{
			return true;
		}
	}
	return false;
}
*/
stock bool:IsValidPlayer(Client, bool:AllowBot = true, bool:AllowDeath = true)
{
	if (Client < 1 || Client > MaxClients)
		return false;
	if (!IsClientConnected(Client) || !IsClientInGame(Client))
		return false;
	if (!AllowBot)
	{
		if (IsFakeClient(Client))
			return false;
	}

	if (!AllowDeath)
	{
		if (!IsPlayerAlive(Client))
			return false;
	}	
	
	return true;
}

//判断生还者是否已经被控
stock bool:IsPinned(client) {
	new bool:bIsPinned = false;
	if (IsSurvivor(client)) {
		// check if held by:
		if( GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0 ) bIsPinned = true; // smoker
		if( GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0 ) bIsPinned = true; // hunter
		if( GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0 ) bIsPinned = true; // charger carry
		if( GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0 ) bIsPinned = true; // charger pound
		if( GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0 ) bIsPinned = true; // jockey
	}		
	return bIsPinned;
}

stock GetInfectedCount()
{
	new index = 0;
	new i;
	for(i = 1; i <= MaxClients; i++)
	{
		if(player_data[i][Intelligence] > 0)
		{
			index++;
		}	
	}
	return index;
}
//获取实血
stock GetSurvivorPermHealth(client)
{
	return GetEntProp(client, Prop_Send, "m_iHealth");
}
//设置实血
stock SetSurvivorPermHealth(client, health)
{
	SetEntProp(client, Prop_Send, "m_iHealth", health);
}
//判断是否倒地
stock bool:IsPlayerIncap(client)
{
	return bool:GetEntProp(client, Prop_Send, "m_isIncapacitated");
}

public Action timer_gascan(Handle timer, any victim)
{
	SDKHooks_TakeDamage(victim, 0, 0, 100.0, DMG_BURN);
}
public void GetClientLevel(Client)
{
	if(player_data[Client][LV] <= 10)
	{
		text1[Client]="初入修仙";
	}
    if(10 < player_data[Client][LV] <= 20)
	{
		if(player_data[Client][LV] == 11)
		{
			text1[Client]="初玄境一级";
		}
		if(player_data[Client][LV] == 12)
		{
			text1[Client]="初玄境二级";
		}
		if(player_data[Client][LV] == 13)
		{
			text1[Client]="初玄境三级";
		}
		if(player_data[Client][LV] == 14)
		{
			text1[Client]="初玄境四级";
		}
		if(player_data[Client][LV] == 15)
		{
			text1[Client]="初玄境五级";
		}
		if(player_data[Client][LV] == 16)
		{
			text1[Client]="初玄境六级";
		}
		if(player_data[Client][LV] == 17)
		{
			text1[Client]="初玄境七级";
		}
		if(player_data[Client][LV] == 18)
		{
			text1[Client]="初玄境八级";
		}
		if(player_data[Client][LV] == 19)
		{
			text1[Client]="初玄境九级";
		}
		if(player_data[Client][LV] == 20)
		{
			text1[Client]="初玄境十级";
		}
	}
	if(20 < player_data[Client][LV] <= 30)
	{
		if(player_data[Client][LV] == 21)
		{
			text1[Client]="入玄境一级";
		}
		if(player_data[Client][LV] == 22)
		{
			text1[Client]="入玄境二级";
		}
		if(player_data[Client][LV] == 23)
		{
			text1[Client]="入玄境三级";
		}
		if(player_data[Client][LV] == 24)
		{
			text1[Client]="入玄境四级";
		}
		if(player_data[Client][LV] == 25)
		{
			text1[Client]="入玄境五级";
		}
		if(player_data[Client][LV] == 26)
		{
			text1[Client]="入玄境六级";
		}
		if(player_data[Client][LV] == 27)
		{
			text1[Client]="入玄境七级";
		}
		if(player_data[Client][LV] == 28)
		{
			text1[Client]="入玄境八级";
		}
		if(player_data[Client][LV] == 29)
		{
			text1[Client]="入玄境九级";
		}
		if(player_data[Client][LV] == 30)
		{
			text1[Client]="入玄境十级";
		}
	}
	if(30 < player_data[Client][LV] <= 40)
	{
		if(player_data[Client][LV] == 31)
		{
			text1[Client]="真玄境一级";
		}
		if(player_data[Client][LV] == 32)
		{
			text1[Client]="真玄境二级";
		}
		if(player_data[Client][LV] == 33)
		{
			text1[Client]="真玄境三级";
		}
		if(player_data[Client][LV] == 34)
		{
			text1[Client]="真玄境四级";
		}
		if(player_data[Client][LV] == 35)
		{
			text1[Client]="真玄境五级";
		}
		if(player_data[Client][LV] == 36)
		{
			text1[Client]="真玄境六级";
		}
		if(player_data[Client][LV] == 37)
		{
			text1[Client]="真玄境七级";
		}
		if(player_data[Client][LV] == 38)
		{
			text1[Client]="真玄境八级";
		}
		if(player_data[Client][LV] == 39)
		{
			text1[Client]="真玄境九级";
		}
		if(player_data[Client][LV] == 40)
		{
			text1[Client]="真玄境十级";
		}
	}
	if(40 < player_data[Client][LV] <= 50)
	{
		if(player_data[Client][LV] == 41)
		{
			text1[Client]="灵玄境一级";
		}
		if(player_data[Client][LV] == 42)
		{
			text1[Client]="灵玄境二级";
		}
		if(player_data[Client][LV] == 43)
		{
			text1[Client]="灵玄境三级";
		}
		if(player_data[Client][LV] == 44)
		{
			text1[Client]="灵玄境四级";
		}
		if(player_data[Client][LV] == 45)
		{
			text1[Client]="灵玄境五级";
		}
		if(player_data[Client][LV] == 46)
		{
			text1[Client]="灵玄境六级";
		}
		if(player_data[Client][LV] == 47)
		{
			text1[Client]="灵玄境七级";
		}
		if(player_data[Client][LV] == 48)
		{
			text1[Client]="灵玄境八级";
		}
		if(player_data[Client][LV] == 49)
		{
			text1[Client]="灵玄境九级";
		}
		if(player_data[Client][LV] == 50)
		{
			text1[Client]="灵玄境十级";
		}
	}
	if(50 < player_data[Client][LV] <= 60)
	{
		if(player_data[Client][LV] == 51)
		{
			text1[Client]="地玄境一级";
		}
		if(player_data[Client][LV] == 52)
		{
			text1[Client]="地玄境二级";
		}
		if(player_data[Client][LV] == 53)
		{
			text1[Client]="地玄境三级";
		}
		if(player_data[Client][LV] == 54)
		{
			text1[Client]="地玄境四级";
		}
		if(player_data[Client][LV] == 55)
		{
			text1[Client]="地玄境五级";
		}
		if(player_data[Client][LV] == 56)
		{
			text1[Client]="地玄境六级";
		}
		if(player_data[Client][LV] == 57)
		{
			text1[Client]="地玄境七级";
		}
		if(player_data[Client][LV] == 58)
		{
			text1[Client]="地玄境八级";
		}
		if(player_data[Client][LV] == 59)
		{
			text1[Client]="地玄境九级";
		}
		if(player_data[Client][LV] == 60)
		{
			text1[Client]="地玄境十级";
		}
	}
	if(60 < player_data[Client][LV] <= 70)
	{
		if(player_data[Client][LV] == 61)
		{
			text1[Client]="天玄境一级";
		}
		if(player_data[Client][LV] == 62)
		{
			text1[Client]="天玄境二级";
		}
		if(player_data[Client][LV] == 63)
		{
			text1[Client]="天玄境三级";
		}
		if(player_data[Client][LV] == 64)
		{
			text1[Client]="天玄境四级";
		}
		if(player_data[Client][LV] == 65)
		{
			text1[Client]="天玄境五级";
		}
		if(player_data[Client][LV] == 66)
		{
			text1[Client]="天玄境六级";
		}
		if(player_data[Client][LV] == 67)
		{
			text1[Client]="天玄境七级";
		}
		if(player_data[Client][LV] == 68)
		{
			text1[Client]="天玄境八级";
		}
		if(player_data[Client][LV] == 69)
		{
			text1[Client]="天玄境九级";
		}
		if(player_data[Client][LV] == 70)
		{
			text1[Client]="天玄境十级";
		}
	}
	if(70 < player_data[Client][LV] <= 80)
	{
		if(player_data[Client][LV] == 71)
		{
			text1[Client]="王玄境一级";
		}
		if(player_data[Client][LV] == 72)
		{
			text1[Client]="王玄境二级";
		}
		if(player_data[Client][LV] == 73)
		{
			text1[Client]="王玄境三级";
		}
		if(player_data[Client][LV] == 74)
		{
			text1[Client]="王玄境四级";
		}
		if(player_data[Client][LV] == 75)
		{
			text1[Client]="王玄境五级";
		}
		if(player_data[Client][LV] == 76)
		{
			text1[Client]="王玄境六级";
		}
		if(player_data[Client][LV] == 77)
		{
			text1[Client]="王玄境七级";
		}
		if(player_data[Client][LV] == 78)
		{
			text1[Client]="王玄境八级";
		}
		if(player_data[Client][LV] == 79)
		{
			text1[Client]="王玄境九级";
		}
		if(player_data[Client][LV] == 80)
		{
			text1[Client]="王玄境十级";
		}
	}
	if(80 < player_data[Client][LV] <= 90)
	{
		if(player_data[Client][LV] == 81)
		{
			text1[Client]="霸玄境一级";
		}
		if(player_data[Client][LV] == 82)
		{
			text1[Client]="霸玄境二级";
		}
		if(player_data[Client][LV] == 83)
		{
			text1[Client]="霸玄境三级";
		}
		if(player_data[Client][LV] == 84)
		{
			text1[Client]="霸玄境四级";
		}
		if(player_data[Client][LV] == 85)
		{
			text1[Client]="霸玄境五级";
		}
		if(player_data[Client][LV] == 86)
		{
			text1[Client]="霸玄境六级";
		}
		if(player_data[Client][LV] == 87)
		{
			text1[Client]="霸玄境七级";
		}
		if(player_data[Client][LV] == 88)
		{
			text1[Client]="霸玄境八级";
		}
		if(player_data[Client][LV] == 89)
		{
			text1[Client]="霸玄境九级";
		}
		if(player_data[Client][LV] == 90)
		{
			text1[Client]="霸玄境十级";
		}
	}
	if(90 < player_data[Client][LV] <= 100)
	{
		if(player_data[Client][LV] == 91)
		{
			text1[Client]="君玄境一级";
		}
		if(player_data[Client][LV] == 92)
		{
			text1[Client]="君玄境二级";
		}
		if(player_data[Client][LV] == 93)
		{
			text1[Client]="君玄境三级";
		}
		if(player_data[Client][LV] == 94)
		{
			text1[Client]="君玄境四级";
		}
		if(player_data[Client][LV] == 95)
		{
			text1[Client]="君玄境五级";
		}
		if(player_data[Client][LV] == 96)
		{
			text1[Client]="君玄境六级";
		}
		if(player_data[Client][LV] == 97)
		{
			text1[Client]="君玄境七级";
		}
		if(player_data[Client][LV] == 98)
		{
			text1[Client]="君玄境八级";
		}
		if(player_data[Client][LV] == 99)
		{
			text1[Client]="君玄境九级";
		}
		if(player_data[Client][LV] == 100)
		{
			text1[Client]="君玄境十级";
		}
	}
	if(100 < player_data[Client][LV] <= 120)
	{
		if(100 < player_data[Client][LV] <= 102)
		{
			text1[Client]="神元境一级";
		}
		if(102 < player_data[Client][LV] <= 104)
		{
			text1[Client]="神元境二级";
		}
		if(104 < player_data[Client][LV] <= 106)
		{
			text1[Client]="神元境三级";
		}
		if(106 < player_data[Client][LV] <= 108)
		{
			text1[Client]="神元境四级";
		}
		if(108 < player_data[Client][LV] <= 110)
		{
			text1[Client]="神元境五级";
		}
		if(110 < player_data[Client][LV] <= 112)
		{
			text1[Client]="神元境六级";
		}
		if(112 < player_data[Client][LV] <= 114)
		{
			text1[Client]="神元境七级";
		}
		if(114 < player_data[Client][LV] <= 116)
		{
			text1[Client]="神元境八级";
		}
		if(116 < player_data[Client][LV] <= 118)
		{
			text1[Client]="神元境九级";
		}
		if(118 < player_data[Client][LV] <= 120)
		{
			text1[Client]="神元境十级";
		}
	}
	if(120 < player_data[Client][LV] <= 140)
	{
		if(120 < player_data[Client][LV] <= 122)
		{
			text1[Client]="神魂境一级";
		}
		if(122 < player_data[Client][LV] <= 124)
		{
			text1[Client]="神魂境二级";
		}
		if(124 < player_data[Client][LV] <= 126)
		{
			text1[Client]="神魂境三级";
		}
		if(126 < player_data[Client][LV] <= 128)
		{
			text1[Client]="神魂境四级";
		}
		if(128 < player_data[Client][LV] <= 130)
		{
			text1[Client]="神魂境五级";
		}
		if(130 < player_data[Client][LV] <= 132)
		{
			text1[Client]="神魂境六级";
		}
		if(132 < player_data[Client][LV] <= 134)
		{
			text1[Client]="神魂境七级";
		}
		if(134 < player_data[Client][LV] <= 136)
		{
			text1[Client]="神魂境八级";
		}
		if(136 < player_data[Client][LV] <= 138)
		{
			text1[Client]="神魂境九级";
		}
		if(138 < player_data[Client][LV] <= 140)
		{
			text1[Client]="神魂境十级";
		}
	}
	if(140 < player_data[Client][LV] <= 160)
	{
		if(140 < player_data[Client][LV] <= 142)
		{
			text1[Client]="神劫境一级";
		}
		if(142 < player_data[Client][LV] <= 144)
		{
			text1[Client]="神劫境二级";
		}
		if(144 < player_data[Client][LV] <= 146)
		{
			text1[Client]="神劫境三级";
		}
		if(146 < player_data[Client][LV] <= 148)
		{
			text1[Client]="神劫境四级";
		}
		if(148 < player_data[Client][LV] <= 150)
		{
			text1[Client]="神劫境五级";
		}
		if(150 < player_data[Client][LV] <= 152)
		{
			text1[Client]="神劫境六级";
		}
		if(152 < player_data[Client][LV] <= 154)
		{
			text1[Client]="神劫境七级";
		}
		if(154 < player_data[Client][LV] <= 156)
		{
			text1[Client]="神劫境八级";
		}
		if(156 < player_data[Client][LV] <= 158)
		{
			text1[Client]="神劫境九级";
		}
		if(158 < player_data[Client][LV] <= 160)
		{
			text1[Client]="神劫境十级";
		}
	}
	if(160 < player_data[Client][LV] <= 180)
	{
		if(160 < player_data[Client][LV] <= 162)
		{
			text1[Client]="神灵境一级";
		}
		if(162 < player_data[Client][LV] <= 164)
		{
			text1[Client]="神灵境二级";
		}
		if(164 < player_data[Client][LV] <= 166)
		{
			text1[Client]="神灵境三级";
		}
		if(166 < player_data[Client][LV] <= 168)
		{
			text1[Client]="神灵境四级";
		}
		if(168 < player_data[Client][LV] <= 170)
		{
			text1[Client]="神灵境五级";
		}
		if(170 < player_data[Client][LV] <= 172)
		{
			text1[Client]="神灵境六级";
		}
		if(172 < player_data[Client][LV] <= 174)
		{
			text1[Client]="神灵境七级";
		}
		if(174 < player_data[Client][LV] <= 176)
		{
			text1[Client]="神灵境八级";
		}
		if(176 < player_data[Client][LV] <= 178)
		{
			text1[Client]="神灵境九级";
		}
		if(178 < player_data[Client][LV] <= 180)
		{
			text1[Client]="神灵境十级";
		}
	}
	if(180 < player_data[Client][LV] <= 200)
	{
		if(180 < player_data[Client][LV] <= 182)
		{
			text1[Client]="神王境一级";
		}
		if(182 < player_data[Client][LV] <= 184)
		{
			text1[Client]="神王境二级";
		}
		if(184 < player_data[Client][LV] <= 186)
		{
			text1[Client]="神王境三级";
		}
		if(186 < player_data[Client][LV] <= 188)
		{
			text1[Client]="神王境四级";
		}
		if(188 < player_data[Client][LV] <= 190)
		{
			text1[Client]="神王境五级";
		}
		if(190 < player_data[Client][LV] <= 192)
		{
			text1[Client]="神王境六级";
		}
		if(192 < player_data[Client][LV] <= 194)
		{
			text1[Client]="神王境七级";
		}
		if(194 < player_data[Client][LV] <= 196)
		{
			text1[Client]="神王境八级";
		}
		if(196 < player_data[Client][LV] <= 198)
		{
			text1[Client]="神王境九级";
		}
		if(198 < player_data[Client][LV] <= 200)
		{
			text1[Client]="神王境十级";
		}
	}
	if(200 < player_data[Client][LV] <= 220)
	{
		if(200 < player_data[Client][LV] <= 202)
		{
			text1[Client]="神君境一级";
		}
		if(202 < player_data[Client][LV] <= 204)
		{
			text1[Client]="神君境二级";
		}
		if(204 < player_data[Client][LV] <= 206)
		{
			text1[Client]="神君境三级";
		}
		if(206 < player_data[Client][LV] <= 208)
		{
			text1[Client]="神君境四级";
		}
		if(208 < player_data[Client][LV] <= 210)
		{
			text1[Client]="神君境五级";
		}
		if(210 < player_data[Client][LV] <= 212)
		{
			text1[Client]="神君境六级";
		}
		if(212 < player_data[Client][LV] <= 214)
		{
			text1[Client]="神君境七级";
		}
		if(214 < player_data[Client][LV] <= 216)
		{
			text1[Client]="神君境八级";
		}
		if(216 < player_data[Client][LV] <= 218)
		{
			text1[Client]="神君境九级";
		}
		if(218 < player_data[Client][LV] <= 220)
		{
			text1[Client]="神君境十级";
		}
	}
	if(220 < player_data[Client][LV] <= 250)
	{
		if(220 < player_data[Client][LV] <= 222)
		{
			text1[Client]="神主境一级";
		}
		if(222 < player_data[Client][LV] <= 224)
		{
			text1[Client]="神主境二级";
		}
		if(224 < player_data[Client][LV] <= 226)
		{
			text1[Client]="神主境三级";
		}
		if(226 < player_data[Client][LV] <= 228)
		{
			text1[Client]="神主境四级";
		}
		if(228 < player_data[Client][LV] <= 230)
		{
			text1[Client]="神主境五级";
		}
		if(230 < player_data[Client][LV] <= 233)
		{
			text1[Client]="神主境六级";
		}
		if(233 < player_data[Client][LV] <= 236)
		{
			text1[Client]="神主境七级";
		}
		if(236 < player_data[Client][LV] <= 240)
		{
			text1[Client]="神主境八级";
		}
		if(240 < player_data[Client][LV] <= 245)
		{
			text1[Client]="神主境九级";
		}
		if(245 < player_data[Client][LV] <= 250)
		{
			text1[Client]="神主境十级";
		}
	}
	if(250 < player_data[Client][LV] <= 9999)
	{
		if(250 < player_data[Client][LV] <= 275)
		{
			text1[Client]="天下第一";
		}
		if(275 < player_data[Client][LV] <= 300)
		{
			text1[Client]="天外飞仙";
		}
		if(300 < player_data[Client][LV] <= 9999)
		{
			text1[Client]="萌新";
		}
	}
}
Update_DATAIP() 
{
	new String:error[256];
	decl String:name[256];
	char context[512];
    ServerCommandEx(context, sizeof(context), "status");
    char lines[7][128];
    ExplodeString(context, "\n", lines, 3, 128);
    ExplodeString(lines[2], " ", lines, 7, 128); 
	ExplodeString(lines[6], ":", lines, 2, 128);
	Server_GetHostName(name,sizeof(name));
	new tickrate = GetConVarInt(FindConVar("sv_maxupdaterate"));
	new Database:db = SQL_DefConnect(error, sizeof(error));
	if (db == null) 
	{
		PrintToServer("【严重错误】:无法连接到MySQL数据库，错误信息：%s", error);
		CPrintToChatAll("{red}【严重错误】:无法连接到MySQL数据库，错误信息：%s", error);
	}
	//SQL_FastQuery(db, "SET lines[6] 'utf8mb4'");
	//SQL_FastQuery(db, "SET name 'utf8mb4'");
	DBStatement hAddQuery;
	if ((hAddQuery = SQL_PrepareQuery(db, Update_serverip, error, sizeof(error))) == null)
	{
		PrintToServer("SQL_PrepareQuery出现错误");
	}
	//下面是参数绑定
	//行数sizeof(args)/sizeof(args[0])
	//SQL_BindParamInt
	SQL_BindParamString(hAddQuery,0,name,true);
	SQL_BindParamInt(hAddQuery,1,tickrate);
	SQL_BindParamString(hAddQuery,2,lines[6],true);
	if (!SQL_Execute(hAddQuery))
	{
		PrintToServer("SQL_Execute出现错误");
		/*
		if(SQL_GetError(db,error,sizeof(error)))
			//CPrintToChatAll("{red}【严重错误】:无法提交信息，错误信息：%s", error);
		else
			//CPrintToChatAll("{red}【严重错误】:无法提交信息，错误信息：未知");	
		*/
	}
	db.Close();
	return true; 
}
MYSQL_INITIP()
{
//全插件只有这个地方是查询
	new String:error[256];
	char context[512];
    ServerCommandEx(context, sizeof(context), "status");
    char lines[7][128];
    ExplodeString(context, "\n", lines, 3, 128);
    ExplodeString(lines[2], " ", lines, 7, 128); 
	ExplodeString(lines[6], ":", lines, 2, 128);
	decl String:name[256];
	Server_GetHostName(name,sizeof(name));
	ArrayList array=CreateArray(40,1);
	//if(GetClientTime(client)>0.0) return true; //已经在游戏则不用查询了
	new Database:db = SQL_DefConnect(error, sizeof(error));
	if (db == null) {
		PrintToServer("【严重错误】:无法连接到MySQL数据库，错误信息：%s", error);
		CPrintToChatAll("{red}【严重错误】:无法连接到MySQL数据库，错误信息：%s", error);
		return false;
	}
	DBStatement hAddQuery;
	if ((hAddQuery = SQL_PrepareQuery(db, SelectIP, error, sizeof(error))) == null)
	{
		PrintToServer("SQL_PrepareQuery出现错误%s",error);
		CPrintToChatAll("SQL_PrepareQuery出现错误%s",error);
		delete db;
		return false;
	}
	//下面是参数绑定
	//行数sizeof(args)/sizeof(args[0])
	SQL_BindParamString(hAddQuery,0,lines[6],true);
	if (!SQL_Execute(hAddQuery))
	{
		PrintToServer("SQL_Execute出现错误");
	}
	if(!SQL_FetchRow(hAddQuery))
	{
		CloseHandle(hAddQuery);
		db.Close();
		SetArrayString(array,0,lines[6]);
		ResizeArray(array,GetArraySize(array)+1);
		// 每增加一条数据都要进行ResizeArray(array,GetArraySize(array)+1)操作
		SetArrayString(array,1,name);
		MySQLTransactionAnne(InitIP,array);		
		return true;
	}
	db.Close();
	return true;	
}
public bool MySQLTransactionAnne(char[] query,ArrayList  array)
{
	
	new String:error[256];
	new String:buffer[256];
	new Database:db = SQL_DefConnect(error, sizeof(error));
	if (db == null) {
		PrintToServer("【严重错误】:无法连接到MySQL数据库，错误信息：%s", error);
		CPrintToChatAll("{red}【严重错误】:无法连接到MySQL数据库，错误信息：%s", error);
		return false;
	}
	
	//SQL_FastQuery(db, "SET lines[6] 'utf8mb4'");
	//SQL_FastQuery(db, "SET name 'utf8mb4'");
	
	DBStatement hAddQuery;
	if ((hAddQuery = SQL_PrepareQuery(db, query, error, sizeof(error))) == null)
	{
		PrintToServer("SQL_PrepareQuery出现错误");
		delete db;
		return false;
	}
	//下面是参数绑定
	//行数sizeof(args)/sizeof(args[0])
	for(int i=0;i<GetArraySize(array);i++)
	{
		GetArrayString(array,i,buffer,sizeof(buffer));
		SQL_BindParamString(hAddQuery,i,buffer,true);
		//PrintToServer("位置%d绑定值为%s\n",i,buffer);
	}
	if (!SQL_Execute(hAddQuery))
	{
	/*
		if(SQL_GetError(db,error,sizeof(error)))
			//CPrintToChatAll("{red}【严重错误】:无法提交信息，错误信息：%s", error);
		else
			//CPrintToChatAll("{red}【严重错误】:无法提交信息，错误信息：未知");	
*/			
	}
	db.Close();
	return true;
}