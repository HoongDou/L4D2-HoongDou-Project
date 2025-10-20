//魔改了树树子的tree_server_rpg插件， https://github.com/GlowingTree880/L4D2_LittlePlugins/blob/2883982d2c5edf8dc6794858695660a83dd39299/ServerRpgWithDatabase/tree_server_rpg.sp#L203
#pragma semicolon 1
#pragma newdecls required

// 头文件
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <colors>
#include "treeutil\treeutil.sp"

#define CVAR_FLAGS FCVAR_NOTIFY
#define DBNAME "l4d2server"
#define DBCHARSET "UTF8MB4"
#define SQL_STATEMENT_MAX_LENGTH 512
//stats相关和menu声音precache
#define INFO_SURVIVOR_ONLY "{olive}[提示]：{lightgreen}本指令仅限生还者使用"
#define BUTTON_SOUND "buttons/button14.wav"

// 表名称
#define TABLENAME_PLAYER_INFORMATION "player_information_table"
#define TABLENAME_PLAYER_MAPS "player_campaign_table"
// 建表语句
#define CREATE_TABLE_PLAYER_INFORMATION \
"CREATE TABLE IF NOT EXISTS player_information_table\
(\
	STEAM_ID VARCHAR(32) PRIMARY KEY NOT NULL DEFAULT 'NO_STEAM_ID_RECORD' COMMENT '玩家 SteamID',\
	Player_Name VARCHAR(64) NOT NULL DEFAULT 'NO_NAME_RECORD' COMMENT '玩家 ID',\
	Last_Play_Time DATETIME DEFAULT NULL COMMENT '玩家最后一次退出服务器时间',\
	Total_Play_Time BIGINT UNSIGNED	NOT NULL DEFAULT 0 COMMENT '玩家总游玩时长',\
	Max_Pre_Play_Time BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '玩家单次最大游玩时长',\
	FF_Count BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '黑枪次数',\
	FF_Damage BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '黑枪总伤害',\
	Player_Deaths BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '玩家死亡数',\
	Player_Kills BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '玩家杀死玩家次数'\
) ENGINE = INNODB DEFAULT CHARSET = UTF8MB4 COMMENT '玩家信息表';"
#define CREATE_TABLE_PLAYER_MAPS \
"CREATE TABLE IF NOT EXISTS player_campaign_table\
(\
	STEAM_ID VARCHAR(32) PRIMARY KEY NOT NULL DEFAULT 'NO_STEAM_ID_RECORD' COMMENT '玩家 SteamID',\
	Player_Name VARCHAR(64) NOT NULL DEFAULT 'NO_NAME_RECORD' COMMENT '玩家 ID',\
	Total_Played_Maps BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '玩家游玩总地图数量'\
) ENGINE = INNODB DEFAULT CHARSET = UTF8MB4 COMMENT '玩家游玩地图数量表';"

// 获取当前年月格式 YYYYMM
#define GET_CURRENT_YEARMONTH(%1) FormatTime(%1, sizeof(%1), "%Y%m", -1)

// 月度表建表语句
#define CREATE_MONTHLY_TABLE_PLAYER_INFORMATION \
"CREATE TABLE IF NOT EXISTS player_information_%s\
(\
	STEAM_ID VARCHAR(32) PRIMARY KEY NOT NULL DEFAULT 'NO_STEAM_ID_RECORD' COMMENT '玩家 SteamID',\
	Player_Name VARCHAR(64) NOT NULL DEFAULT 'NO_NAME_RECORD' COMMENT '玩家 ID',\
	Last_Play_Time DATETIME DEFAULT NULL COMMENT '玩家最后一次退出服务器时间',\
	Total_Play_Time BIGINT UNSIGNED	NOT NULL DEFAULT 0 COMMENT '玩家月度游玩时长',\
	Max_Pre_Play_Time BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '玩家月度单次最大游玩时长',\
	FF_Count BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '月度黑枪次数',\
	FF_Damage BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '月度黑枪总伤害',\
	Player_Deaths BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '月度玩家死亡数',\
	Player_Kills BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '月度玩家杀死玩家次数'\
) ENGINE = INNODB DEFAULT CHARSET = UTF8MB4 COMMENT '玩家月度信息表';"

#define CREATE_MONTHLY_TABLE_PLAYER_MAPS \
"CREATE TABLE IF NOT EXISTS player_campaign_%s\
(\
	STEAM_ID VARCHAR(32) PRIMARY KEY NOT NULL DEFAULT 'NO_STEAM_ID_RECORD' COMMENT '玩家 SteamID',\
	Player_Name VARCHAR(64) NOT NULL DEFAULT 'NO_NAME_RECORD' COMMENT '玩家 ID',\
	Total_Played_Maps BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '玩家月度游玩总地图数量'\
) ENGINE = INNODB DEFAULT CHARSET = UTF8MB4 COMMENT '玩家月度游玩地图数量表';"


// 连接成功失败报错提示
#define DB_CONNECT_SUCCESS "连接数据库：%s 成功"
#define DB_CONNECT_FAIL "连接数据库：%s 失败，错误信息：%s"
#define DB_CONNECT_INVALID_HANDLE "数据库句柄为空，无法连接到数据库：%s"
#define DB_MANAGE_ERROR "对数据库：%s 进行操作时发生错误，错误信息：%s"
#define DB_QUERY_CLIENT_INFO_FAIL "查询玩家：%N 的相关信息失败，错误信息：%s"
#define DB_STEAMID_ERROR_KICK "无法获取您的 SteamID，请重新连接好友网络或重试"
#define DB_CREATE_TABLE_SUCCESS "成功于数据库：%s 中创建数据表：%s %s [%s]"
#define DB_ADD_COLUMN_SUCCESS "成功于数据表：%s 中添加字段：%s [%s]"
#define INFO_PLAYERINFO "※成功获取到玩家：%N 的基本信息：总游玩时长：%s，最大游玩时长：%s，黑枪次数：%d，黑枪伤害：%d，死亡数：%d，击杀数：%d [%s]"
#define INFO_STEAMID_KICK "{olive}[提示]：{lightgreen}无法获取玩家：{olive}%N {lightgreen}的SteamID，已将其踢出"
// 插件日志保存位置
#define LOG_PLAYERMESSAGE_PATH "logs/%s_ChatLog.log"
#define LOG_FILE_PATH "logs/L4D2Server_Database.log"
// SQL 语句
#define DQL_HAS_TABLES "SHOW TABLES LIKE '%s';"
#define DML_UPDATE_PLAYER_INFO_AND_TIME "INSERT INTO %s (STEAM_ID, Player_Name, Last_Play_Time) VALUES ('%s', '%s', NOW()) AS new ON DUPLICATE KEY UPDATE Player_Name = new.Player_Name, Last_Play_Time = new.Last_Play_Time;"
#define DML_UPDATE_PLAYER_INFO "INSERT INTO %s (STEAM_ID, Player_Name) VALUES ('%s', '%s') AS new ON DUPLICATE KEY UPDATE Player_Name = new.Player_Name;"
#define DML_ADD_MAPS "ALTER TABLE %s ADD %s BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '玩家游玩地图：%s 次数';"
#define DML_ADD_MAP_PLAYTIMES "INSERT INTO %s (STEAM_ID, Player_Name, Total_Played_Maps, %s) VALUES ('%s', '%s', 1, 1) AS new ON DUPLICATE KEY UPDATE Total_Played_Maps = %s.Total_Played_Maps + 1, %s = %s.%s + 1;"
#define DQL_PLAYERINFO "SELECT INFO.`Total_Play_Time`, INFO.`Max_Pre_Play_Time`, INFO.`FF_Count`, INFO.`FF_Damage`, INFO.`Player_Deaths`, INFO.`Player_Kills`, CP.`Total_Played_Maps` FROM %s AS INFO, %s AS CP WHERE INFO.`STEAM_ID` = '%s' AND CP.`STEAM_ID` = '%s';"
#define DML_UPDATE_ALL_DATA "UPDATE %s AS INFO, %s AS CP SET INFO.`Total_Play_Time` = INFO.`Total_Play_Time` + %d, INFO.`Last_Play_Time` = NOW(), INFO.`Max_Pre_Play_Time` = \
IF(INFO.`Max_Pre_Play_Time` < %d, %d, INFO.`Max_Pre_Play_Time`), INFO.`FF_Count` = %d, INFO.`FF_Damage` = %d, INFO.`Player_Deaths` = %d, INFO.`Player_Kills` = %d, CP.`Total_Played_Maps` = %d WHERE INFO.`STEAM_ID` = '%s' AND CP.`STEAM_ID` = '%s';"

// 月度表 DML 语句
#define DML_UPDATE_MONTHLY_PLAYER_INFO_AND_TIME "INSERT INTO player_information_%s (STEAM_ID, Player_Name, Last_Play_Time) VALUES ('%s', '%s', NOW()) AS new ON DUPLICATE KEY UPDATE Player_Name = new.Player_Name, Last_Play_Time = new.Last_Play_Time;"
#define DML_UPDATE_MONTHLY_PLAYER_INFO "INSERT INTO player_campaign_%s (STEAM_ID, Player_Name) VALUES ('%s', '%s') AS new ON DUPLICATE KEY UPDATE Player_Name = new.Player_Name;"
#define DML_ADD_MONTHLY_MAPS "ALTER TABLE player_campaign_%s ADD %s BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '玩家月度游玩地图：%s 次数';"
#define DML_ADD_MONTHLY_MAP_PLAYTIMES "INSERT INTO player_campaign_%s (STEAM_ID, Player_Name, Total_Played_Maps, %s) VALUES ('%s', '%s', 1, 1) AS new ON DUPLICATE KEY UPDATE Total_Played_Maps = player_campaign_%s.Total_Played_Maps + 1, %s = player_campaign_%s.%s + 1;"
#define DQL_MONTHLY_PLAYERINFO "SELECT INFO.`Total_Play_Time`, INFO.`Max_Pre_Play_Time`, INFO.`FF_Count`, INFO.`FF_Damage`, INFO.`Player_Deaths`, INFO.`Player_Kills`, CP.`Total_Played_Maps` FROM player_information_%s AS INFO, player_campaign_%s AS CP WHERE INFO.`STEAM_ID` = '%s' AND CP.`STEAM_ID` = '%s';"
#define DML_UPDATE_MONTHLY_ALL_DATA "UPDATE player_information_%s AS INFO, player_campaign_%s AS CP SET INFO.`Total_Play_Time` = INFO.`Total_Play_Time` + %d, INFO.`Last_Play_Time` = NOW(), INFO.`Max_Pre_Play_Time` = \
IF(INFO.`Max_Pre_Play_Time` < %d, %d, INFO.`Max_Pre_Play_Time`), INFO.`FF_Count` = %d, INFO.`FF_Damage` = %d, INFO.`Player_Deaths` = %d, INFO.`Player_Kills` = %d, CP.`Total_Played_Maps` = %d WHERE INFO.`STEAM_ID` = '%s' AND CP.`STEAM_ID` = '%s';"

#define DB_CREATE_MONTHLY_TABLE_SUCCESS "成功于数据库：%s 中创建月度数据表：player_information_%s player_campaign_%s [%s]"
#define DB_ADD_MONTHLY_COLUMN_SUCCESS "成功于月度数据表：player_campaign_%s 中添加字段：%s [%s]"

// 查询类型
enum DQL_DATATYPE
{
	PLAYER_INFORMATION,
	PLAYER_CAMPAIGN,
	QUERY_HAS_TABLES,
	QUERY_HAS_MAPS,
	QUERY_HAS_MONTHLY_TABLES,      
	QUERY_HAS_MONTHLY_MAPS,        
	MONTHLY_PLAYER_INFORMATION,
	RANK_TOTAL_PLAYTIME,
	RANK_MAX_PLAYTIME,
	RANK_PLAYER_DEATHS,
	RANK_PLAYER_KILLS,
	RANK_FF,
	RANK_MAP_PLAYED,
	RANK_PLAYER_ALLRANK,
	RANK_MONTHLY_TOTAL_PLAYTIME,
	RANK_MONTHLY_MAX_PLAYTIME,
	RANK_MONTHLY_PLAYER_DEATHS,
	RANK_MONTHLY_PLAYER_KILLS,
	RANK_MONTHLY_FF,
	RANK_MONTHLY_MAP_PLAYED,
	RANK_MONTHLY_PLAYER_ALLRANK,
	RANK_QUERY_AVAILABLE_MONTHS     
}

// 玩家基本信息结构体
enum struct Player_Info
{
	int Last_Login_Time;
	char Player_SteamID[32];
	void InitInfo()
	{
		this.Last_Login_Time = -1;
		strcopy(this.Player_SteamID, 32, NULL_STRING);
	}
}
Player_Info player_information[MAXPLAYERS + 1];
enum struct Player_Data
{
	int Play_Time;
	int Max_Play_Time;
	int FF_Count;
	int FF_Damage;
	int Player_Deaths;
	int Player_Kills;
	int Total_Played_Maps;
	bool Require_Success;
	bool Not_First_Buy;
	void InitStatus()
	{
		this.Play_Time = this.Max_Play_Time = this.FF_Count = this.FF_Damage = this.Player_Deaths = this.Player_Kills = this.Total_Played_Maps = 0;
		this.Require_Success = this.Not_First_Buy = false;
	}
}
Player_Data player_data[MAXPLAYERS + 1];


public Plugin myinfo = 
{
	name 			= "l4d2server RPG",
	author 			= "夜羽真白,HoongDou",
	description 	= "配合使用 MySQL 数据库记录玩家信息插件",
	version 		= "2.0.0.1",
	url 			= "https://steamcommunity.com/id/saku_ra/"
}

// 数据库全局句柄
Database db_L4D2Server = null;
// ConVars
ConVar g_hRecordLog, g_hRecordMessage, g_hRecordSteamID, g_hAnnounceConnect;
// Chars
char log_file_path[PLATFORM_MAX_PATH] = {'\0'}, message_file_path[PLATFORM_MAX_PATH] = {'\0'};


//全局变量
bool g_bBuckShot[MAXPLAYERS + 1] = {false};

// 加载其他文件

#include "rpgdatabases\rankmenus.sp"

public void OnPluginStart()
{
	char file_name[64] = {'\0'}, query_database[64] = {'\0'};
	g_hRecordLog = CreateConVar("Database_RecordLog", "1", "数据库连接时或操作时是否记录日志", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hRecordMessage = CreateConVar("Database_RecordMessage", "1", "玩家说话或加入退出时是否记录信息", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hRecordSteamID = CreateConVar("Database_RecordSteamID", "1", "玩家说话或加入退出时记录玩家的 STEAMID 与 IP 地址", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hAnnounceConnect = CreateConVar("Database_RecordConnection", "1", "玩家加入退出时是否为其他玩家显示加入退出信息", CVAR_FLAGS, true, 0.0, true, 1.0);
	HookEvent("round_end", evt_UpdateAllData, EventHookMode_PostNoCopy);
	// 战役过图，不会触发 round_end，使用 map_transition 上传数据
	HookEvent("map_transition", evt_UpdateAllData, EventHookMode_PostNoCopy);
	// 救援载具离开，不会触发 round_end，使用 finale_vehicle_leaving 上传数据
	HookEvent("finale_vehicle_leaving", evt_UpdateAllData, EventHookMode_PostNoCopy);
	HookEvent("player_disconnect", evt_PlayerDisconnect, EventHookMode_Pre);
	// 玩家更改名字时，上传一次名字
	HookEvent("player_changename", evt_PlayerNameChange, EventHookMode_Post);
	// 重置玩家基本信息
	ResetLogInfos(true);
	// 插件启动时，首次连接数据库
	if (db_L4D2Server != null)
	{
		delete db_L4D2Server;
		db_L4D2Server = null;
	}
	if (ConnectDatabase())
	{
		// 插件启动时，检查数据库中是否有数据表，没有则创建新的数据表
		FormatEx(query_database, sizeof(query_database), DQL_HAS_TABLES, TABLENAME_PLAYER_INFORMATION);
		DQL_QueryData(-1, QUERY_HAS_TABLES, query_database);
		FormatEx(query_database, sizeof(query_database), DQL_HAS_TABLES, TABLENAME_PLAYER_MAPS);
		DQL_QueryData(-1, QUERY_HAS_TABLES, query_database);

		char yearmonth[16] = {'\0'};
		GET_CURRENT_YEARMONTH(yearmonth);
		FormatEx(query_database, sizeof(query_database), DQL_HAS_TABLES, "player_information_%s", yearmonth);
		DQL_QueryData(-1, QUERY_HAS_MONTHLY_TABLES, query_database);
		FormatEx(query_database, sizeof(query_database), DQL_HAS_TABLES, "player_campaign_%s", yearmonth);
		DQL_QueryData(-1, QUERY_HAS_MONTHLY_TABLES, query_database);
	}
	// 记录玩家日志与插件运行日志
	FormatEx(file_name, sizeof(file_name), LOG_PLAYERMESSAGE_PATH, GetCurrentDate(false));
	BuildPath(Path_SM, message_file_path, sizeof(message_file_path), file_name);
	BuildPath(Path_SM, log_file_path, sizeof(log_file_path), LOG_FILE_PATH);

	RegConsoleCmd("sm_stats", Cmd_Stats, "显示玩家统计信息");
	// 黑枪统计相关的事件
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post); 
	// 加载其他文件
	RankMenus_OnModuleStart();
}
// sm plugins unload_all 不会触发每个插件的 OnPluginEnd 函数，需要手动卸载
public void OnPluginEnd()
{
	UpdateAllPlayerData();
}

public void OnMapStart()
{
	// 预缓存声音
	PrecacheSound(BUTTON_SOUND, true);
	// 更换新地图时，重新连接一次数据库
	if (db_L4D2Server != null)
	{
		delete db_L4D2Server;
		db_L4D2Server = null;
	}
	if (ConnectDatabase())
	{
		// 识别当前地图名称
		char map_name[32] = {'\0'}, file_name[64] = {'\0'}, sql_statement[128] = {'\0'};
		GetCurrentMap(map_name, sizeof(map_name));
		// 玩家游玩地图表中是否有此地图名称，无则添加新列
		FormatEx(sql_statement, sizeof(sql_statement), "SELECT %s FROM %s;", map_name, TABLENAME_PLAYER_MAPS);
		DQL_QueryData(-1, QUERY_HAS_MAPS, sql_statement);
		char yearmonth[16] = {'\0'};
		GET_CURRENT_YEARMONTH(yearmonth);
		FormatEx(sql_statement, sizeof(sql_statement), "SELECT %s FROM player_campaign_%s;", map_name, yearmonth);
		DQL_QueryData(-1, QUERY_HAS_MONTHLY_MAPS, sql_statement);
		FormatEx(file_name, sizeof(file_name), LOG_PLAYERMESSAGE_PATH, GetCurrentDate(false));
		BuildPath(Path_SM, message_file_path, sizeof(message_file_path), file_name);
		if (g_hRecordLog.BoolValue)
		{
			FormatEx(sql_statement, sizeof(sql_statement), "当前地图：%s 开始，连接数据库：%s 成功 [%s]", map_name, DBNAME, GetCurrentDate(true));
			SaveDatabaseLogMessage(sql_statement);
		}
	}
}

// *********************
// 		 玩家相关
// *********************
// 重置玩家登录信息
void ResetLogInfos(bool reset_all, int client = -1)
{
	if (reset_all && client == -1)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			player_information[i].InitInfo();
			player_data[i].InitStatus();
		}
	}
	else if (!reset_all && IsValidClient(client))
	{
		player_information[client].InitInfo();
		player_data[client].InitStatus();
	}
}
// 玩家完全进入服务器时，加入玩家信息条目
void InsertPlayerInfo(int client, const char[] steamID)
{
	player_information[client].Last_Login_Time = GetTime();
	strcopy(player_information[client].Player_SteamID, 32, steamID);
}
// 获取玩家此次游玩时间
int GetPlayTime(int client, const char[] steamID)
{
	if (player_information[client].Last_Login_Time != -1 && strcmp(player_information[client].Player_SteamID, steamID) == 0)
	{
		return player_information[client].Last_Login_Time;
	}
	return -1;
}
// 玩家进入服务器
public void OnClientPostAdminCheck(int client)
{
	if (IsValidClient(client) && !IsFakeClient(client))
	{
		char map_name[32] = {'\0'}, steamID[32] = {'\0'}, player_name[MAX_NAME_LENGTH] = {'\0'}, player_ip[32] = {'\0'}, sql_statement[2 * SQL_STATEMENT_MAX_LENGTH] = {'\0'};
		GetCurrentMap(map_name, sizeof(map_name));
		if (GetClientAuthId(client, AuthId_Steam2, steamID, sizeof(steamID)))
		{
			GetClientIP(client, player_ip, sizeof(player_ip));
			GetClientName(client, player_name, sizeof(player_name));
			if (g_hRecordLog.BoolValue && g_hRecordSteamID.BoolValue)
			{
				FormatEx(sql_statement, sizeof(sql_statement), "※玩家：%N (STEAMID：%s，IP：%s) 加入服务器 [%s]", client, steamID, player_ip, GetCurrentDate(true));
				SaveDatabaseLogMessage(sql_statement);
			}
			else if (g_hRecordLog.BoolValue)
			{
				FormatEx(sql_statement, sizeof(sql_statement), "※玩家：%N 加入服务器 [%s]", client, GetCurrentDate(true));
				SaveDatabaseLogMessage(sql_statement);
			}
			// 根据当前加入的玩家的 STEAMID 将当前玩家信息加入到数组与数据库中
			InsertPlayerInfo(client, steamID);
			UpdateNames(sql_statement, steamID, player_name);
			char yearmonth[16] = {'\0'};
			GET_CURRENT_YEARMONTH(yearmonth);
			UpdateMonthlyNames(sql_statement, yearmonth, steamID, player_name);
			
			// 增加玩家游玩的地图数量
			FormatEx(sql_statement, sizeof(sql_statement), DML_ADD_MAP_PLAYTIMES, TABLENAME_PLAYER_MAPS, map_name, steamID, player_name, TABLENAME_PLAYER_MAPS, map_name, TABLENAME_PLAYER_MAPS, map_name);
			DML_ManageData(sql_statement);
			FormatEx(sql_statement, sizeof(sql_statement), DML_ADD_MONTHLY_MAP_PLAYTIMES, yearmonth, map_name, steamID, player_name, yearmonth, map_name, yearmonth, map_name);
			DML_ManageData(sql_statement);
			// 查询当前玩家的所有信息
			FormatEx(sql_statement, sizeof(sql_statement), DQL_PLAYERINFO, TABLENAME_PLAYER_INFORMATION, TABLENAME_PLAYER_MAPS, steamID, steamID);
			DQL_QueryData(client, PLAYER_INFORMATION, sql_statement);
			FormatEx(sql_statement, sizeof(sql_statement), DQL_MONTHLY_PLAYERINFO, yearmonth, yearmonth, steamID, steamID);
			DQL_QueryData(client, MONTHLY_PLAYER_INFORMATION, sql_statement);
			player_data[client].Require_Success = true;
			if (g_hAnnounceConnect.BoolValue)
			{
				DataPack pack = new DataPack();
				pack.WriteCell(client);
				pack.WriteString(steamID);
				pack.WriteString(player_ip);
				CreateTimer(SHOW_DELAY, Timer_AnnounceJoin, pack);
			}
		}
		else
		{
			KickClient(client, DB_STEAMID_ERROR_KICK);
			CPrintToChatAll(INFO_STEAMID_KICK, client);
			ResetLogInfos(false, client);
		}
	}
}
public Action Timer_AnnounceJoin(Handle timer, DataPack pack)
{
	if (pack != null)
	{
		pack.Reset();
		int client = pack.ReadCell();
		char steamID[32] = {'\0'}, player_ip[32] = {'\0'};
		pack.ReadString(steamID, sizeof(steamID));
		pack.ReadString(player_ip, sizeof(player_ip));
		if (g_hRecordSteamID.BoolValue)
		{
			if (player_data[client].Require_Success && player_data[client].Play_Time != 0)
			{
				CPrintToChatAll("{olive}%N {lightgreen}<%s> {green}\n本服务器内游玩时间：{olive}%s", client, steamID, FormatDuration(player_data[client].Play_Time));
			}
		}
		else if (g_hAnnounceConnect.BoolValue)
		{
			if (player_data[client].Require_Success && player_data[client].Play_Time != 0)
			{
				CPrintToChatAll("{olive}%N {green}\n本服务器内游玩时间：{olive}%s", client, FormatDuration(player_data[client].Play_Time));
			}
		}
		delete pack;
	}
	return Plugin_Stop;
}
// 玩家退出服务器
public void evt_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	SetEventBroadcast(event, true);
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidClient(client) && !IsFakeClient(client))
	{
		char steamID[32] = {'\0'}, player_ip[32] = {'\0'}, reason[64] = {'\0'}, sql_statement[SQL_STATEMENT_MAX_LENGTH] = {'\0'};
		event.GetString("reason", reason, sizeof(reason));
		// 验证退出的玩家是否可以获取 STEAMID 同时与玩家信息数组中对应玩家的 STEAMID 是否相同同时是否已经读取信息
		bool have_steamID = GetClientAuthId(client, AuthId_Steam2, steamID, sizeof(steamID));
		if (!have_steamID && player_data[client].Require_Success && strcmp(player_information[client].Player_SteamID, NULL_STRING) != 0)
		{
			strcopy(steamID, sizeof(steamID), player_information[client].Player_SteamID);
		}
		else if (!have_steamID)
		{
			KickClient(client, DB_STEAMID_ERROR_KICK);
			CPrintToChatAll(INFO_STEAMID_KICK, client);
			ResetLogInfos(false, client);
			return;
		}
		GetClientIP(client, player_ip, sizeof(player_ip));
		// 更新玩家其他信息
		UpdatePlayerData(client, steamID);
		if (g_hRecordLog.BoolValue && g_hRecordSteamID.BoolValue)
		{
			if (g_hAnnounceConnect.BoolValue)
			{
				//CPrintToChatAll("{olive}%N {lightgreen}<%s> {green}已退出，原因：{olive}%s", client, steamID, reason);
			}
			FormatEx(sql_statement, sizeof(sql_statement), "※玩家：%N （STEAMID：%s，IP：%s） 退出服务器，原因：%s，所有信息上传成功 [%s]", client, steamID, player_ip, reason, GetCurrentDate(true));
			SaveDatabaseLogMessage(sql_statement);
		}
		else if (g_hRecordLog.BoolValue)
		{
			if (g_hAnnounceConnect.BoolValue)
			{
				//CPrintToChatAll("{olive}%N {green}已退出，原因：{olive}%s", client, reason);
			}
			FormatEx(sql_statement, sizeof(sql_statement), "※玩家：%N 退出服务器，原因：%s，所有信息上传成功 [%s]", client, reason, GetCurrentDate(true));
			SaveDatabaseLogMessage(sql_statement);
		}
		g_bBuckShot[client] = false;
		ResetLogInfos(false, client);
	}
}
public void evt_UpdateAllData(Event event, const char[] name, bool dontBroadcast)
{
	UpdateAllPlayerData();
}
// 玩家改名时，上传一次 STEAMID 与名字，其余信息不上传
public void evt_PlayerNameChange(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	char steamID[32] = {'\0'}, player_ip[32] = {'\0'}, old_name[MAX_NAME_LENGTH] = {'\0'}, new_name[MAX_NAME_LENGTH] = {'\0'}, sql_statement[SQL_STATEMENT_MAX_LENGTH] = {'\0'};
	event.GetString("oldname", old_name, sizeof(old_name));
	event.GetString("newname", new_name, sizeof(new_name));
	bool have_steamID = GetClientAuthId(client, AuthId_Steam2, steamID, sizeof(steamID));
	if (!have_steamID && strcmp(player_information[client].Player_SteamID, NULL_STRING) != 0)
	{
		strcopy(steamID, sizeof(steamID), player_information[client].Player_SteamID);
	}
	else if (!have_steamID)
	{
		KickClient(client, DB_STEAMID_ERROR_KICK);
		CPrintToChatAll(INFO_STEAMID_KICK, client);
		ResetLogInfos(false, client);
		return;
	}
	GetClientIP(client, player_ip, sizeof(player_ip));
	if (g_hRecordMessage.BoolValue)
	{
		if (g_hRecordSteamID.BoolValue)
		{
			FormatEx(sql_statement, sizeof(sql_statement), "※玩家：%s （STEAMID：%s，IP：%s） 已将名称更改为 %s [%s]", old_name, steamID, player_ip, new_name, GetCurrentDate(true));
		}
		else
		{
			FormatEx(sql_statement, sizeof(sql_statement), "※玩家：%s 已将名称更改为 %s [%s]", old_name, new_name, GetCurrentDate(true));
		}
		SaveDatabaseLogMessage(sql_statement);
	}
	UpdateNames(sql_statement, steamID, new_name);
	char yearmonth[16] = {'\0'};
	GET_CURRENT_YEARMONTH(yearmonth);
	UpdateMonthlyNames(sql_statement, yearmonth, steamID, new_name);
}
void UpdateAllPlayerData()
{
	char steamID[32] = {'\0'};
	for (int client = 1; client <= MaxClients; client++)
	{
		player_data[client].Not_First_Buy = false;
		if (IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client))
		{
			bool have_steamID = GetClientAuthId(client, AuthId_Steam2, steamID, sizeof(steamID));
			if (!have_steamID && strcmp(player_information[client].Player_SteamID, NULL_STRING) != 0)
			{
				strcopy(steamID, sizeof(steamID), player_information[client].Player_SteamID);
			}
			else if (!have_steamID)
			{
				KickClient(client, DB_STEAMID_ERROR_KICK);
				CPrintToChatAll(INFO_STEAMID_KICK, client);
				ResetLogInfos(false, client);
				continue;
			}
			UpdatePlayerData(client, steamID);
			char yearmonth[16] = {'\0'};
			GET_CURRENT_YEARMONTH(yearmonth);
			UpdateMonthlyPlayerData(client, steamID, yearmonth);
		}
	}
}
void UpdateNames(char[] sql_statement, char[] steamID, char[] player_name)
{
	FormatEx(sql_statement, SQL_STATEMENT_MAX_LENGTH, DML_UPDATE_PLAYER_INFO_AND_TIME, TABLENAME_PLAYER_INFORMATION, steamID, player_name);
	DML_ManageData(sql_statement);
	FormatEx(sql_statement, SQL_STATEMENT_MAX_LENGTH, DML_UPDATE_PLAYER_INFO, TABLENAME_PLAYER_MAPS, steamID, player_name);
	DML_ManageData(sql_statement);
}
void UpdatePlayerData(int client, char[] steamID)
{
	char sql_statement[3 * SQL_STATEMENT_MAX_LENGTH] = {'\0'}, player_name[MAX_NAME_LENGTH] = {'\0'};
	int last_login_time = GetPlayTime(client, steamID);
	GetClientName(client, player_name, sizeof(player_name));
	if (last_login_time != -1)
	{
		UpdateNames(sql_statement, steamID, player_name);
		int round_duration = GetTime() - last_login_time;
		FormatEx(sql_statement, sizeof(sql_statement), DML_UPDATE_ALL_DATA
		, TABLENAME_PLAYER_INFORMATION, TABLENAME_PLAYER_MAPS, round_duration, round_duration, round_duration, 
		player_data[client].FF_Count, player_data[client].FF_Damage, player_data[client].Player_Deaths, player_data[client].Player_Kills, 
		player_data[client].Total_Played_Maps, steamID, steamID);
		DML_ManageData(sql_statement);
	}
}

// 玩家死亡事件处理
public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	
	// 记录受害者死亡
	if (IsValidClient(victim) && !IsFakeClient(victim))
	{
		player_data[victim].Player_Deaths++;
	}
	
	// 记录攻击者击杀（如果是玩家击杀玩家）
	if (IsValidClient(attacker) && !IsFakeClient(attacker) && attacker != victim && IsValidClient(victim))
	{
		// 检查双方是否都是生还者
		if (GetClientTeam(attacker) == 2 && GetClientTeam(victim) == 2)
		{
			player_data[attacker].Player_Kills++;
		}
	}
}

// 保存数据库日志信息到文件中
void SaveDatabaseLogMessage(const char[] message)
{
	// 检查文件路径是否有效
	if (log_file_path[0] == '\0')
	{
		PrintToServer("错误：日志文件路径未初始化");
		return;
	}

	File logFile = OpenFile(log_file_path, "a");
	if (logFile == null)
	{
		PrintToServer("错误：无法打开日志文件 %s", log_file_path);
		return;
	}
	
	logFile.WriteLine(message);
	delete logFile;
}
// 保存玩家说话或加入离开信息到日志文件中
void SavePlayerMessage(const char[] message)
{
	// 检查文件路径是否有效
	if (message_file_path[0] == '\0')
	{
		PrintToServer("错误：消息文件路径未初始化");
		return;
	}
	
	File msgFile = OpenFile(message_file_path, "a");
	if (msgFile == null)
	{
		PrintToServer("错误：无法打开消息文件 %s", message_file_path);
		return;
	}
	
	msgFile.WriteLine(message);
	delete msgFile;
}

// *********************
// 		数据库相关
// *********************
// 插件连接数据库
bool ConnectDatabase()
{
	if (SQL_CheckConfig(DBNAME))
	{
		char connect_error[128] = {'\0'};
		db_L4D2Server = SQL_Connect(DBNAME, true, connect_error, sizeof(connect_error));
		if (db_L4D2Server != null)
		{
			db_L4D2Server.SetCharset(DBCHARSET);
			PrintToServer(DB_CONNECT_SUCCESS, DBNAME);
			return true;
		}
		else
		{
			PrintToServer(DB_CONNECT_FAIL, DBNAME, connect_error);
		}
	}
	return false;
}
// 使用 DML 语句向数据库进行操作，使用句柄返回操作的结果
void DML_ManageData(const char[] information)
{
	if (db_L4D2Server != null)
	{
		db_L4D2Server.Query(SQL_DML_QueryCallback, information);
	}
	else
	{
		PrintToServer(DB_CONNECT_INVALID_HANDLE, DBNAME);
	}
}
void SQL_DML_QueryCallback(Database db, DBResultSet results, const char[] error, any data)
{
	if (db != null)
	{
		delete db;
		db = null;
	}
	else if (db == null)
	{
		return;
	}
	else if (strcmp(error, NULL_STRING) != 0)
	{
		PrintToServer(DB_MANAGE_ERROR, DBNAME, error);
	}
}
// 使用 DQL 语句向数据库进行信息查询，使用句柄返回查询的结果
void DQL_QueryData(int client = -1, DQL_DATATYPE DataType, const char[] information)
{
	DataPack dp_ClientPack = new DataPack();
	if (db_L4D2Server != null && IsValidClient(client))
	{
		dp_ClientPack.WriteCell(client);
		dp_ClientPack.WriteCell(DataType);
		db_L4D2Server.Query(SQL_DQL_QueryCallback, information, dp_ClientPack);
	}
	else if (db_L4D2Server != null)
	{
		dp_ClientPack.WriteCell(-1);
		dp_ClientPack.WriteCell(DataType);
		db_L4D2Server.Query(SQL_DQL_QueryCallback, information, dp_ClientPack);
	}
}
void SQL_DQL_QueryCallback(Database db, DBResultSet results, const char[] error, DataPack client_pack = null)
{
	// 读取数据包信息
	client_pack.Reset();
	int client = client_pack.ReadCell();
	DQL_DATATYPE data_type = client_pack.ReadCell();
	delete client_pack;
	if (IsValidClient(client))
	{
		if (db != null && results != null && strcmp(error, NULL_STRING) == 0)
		{
			switch (data_type)
			{
				case PLAYER_INFORMATION:
				{
					DQL_QueryPlayerInformation(client, results, PLAYER_INFORMATION);
				}
				case MONTHLY_PLAYER_INFORMATION:
				{
					DQL_QueryPlayerInformation(client, results, MONTHLY_PLAYER_INFORMATION);
				}
			}
		}
		else
		{
			PrintToServer(DB_QUERY_CLIENT_INFO_FAIL, client, error);
		}
	}
	else
	{
		if (db != null && results != null && strcmp(error, NULL_STRING) == 0)
		{
			switch (data_type)
			{
				case QUERY_HAS_TABLES:
				{
					DQL_QueryOtherInformation(results, QUERY_HAS_TABLES);
				}
				case QUERY_HAS_MONTHLY_TABLES:
				{
					DQL_QueryOtherInformation(results, QUERY_HAS_MONTHLY_TABLES);
				}
				case QUERY_HAS_MONTHLY_MAPS:
				{
					DQL_QueryOtherInformation(results, QUERY_HAS_MONTHLY_MAPS);
				}
				case RANK_QUERY_AVAILABLE_MONTHS:
				{
					// 这个由rankmenus.sp处理
				}
			}
		}
		else
		{
			char map_name[32] = {'\0'};
			GetCurrentMap(map_name, sizeof(map_name));
			if (strncmp(error[16], map_name, strlen(map_name)) == 0 && data_type == QUERY_HAS_MAPS)
			{
				DQL_QueryOtherInformation(results, QUERY_HAS_MAPS);
			}
			else
			{
				PrintToServer(DB_MANAGE_ERROR, DBNAME, error);
			}
		}
	}
	delete db;
	delete results;
	db = null;
	results = null;
}
// 查询玩家信息
void DQL_QueryPlayerInformation(int client, DBResultSet results, DQL_DATATYPE DataType)
{
	bool has_value = false;
	char sql_statement[SQL_STATEMENT_MAX_LENGTH] = {'\0'};
	if (results.RowCount > 0 && DataType == PLAYER_INFORMATION)
	{
		while (results.FetchRow())
		{
			has_value = true;
			player_data[client].Play_Time = results.FetchInt(0);
			player_data[client].Max_Play_Time = results.FetchInt(1);
			player_data[client].FF_Count = results.FetchInt(2);
			player_data[client].FF_Damage = results.FetchInt(3);
			player_data[client].Player_Deaths = results.FetchInt(4);
			player_data[client].Player_Kills = results.FetchInt(5);
			player_data[client].Total_Played_Maps = results.FetchInt(6);
		}
		if (has_value && g_hRecordLog.BoolValue)
		{
			FormatEx(sql_statement, sizeof(sql_statement), INFO_PLAYERINFO, client, FormatDuration(player_data[client].Play_Time), FormatDuration(player_data[client].Max_Play_Time), player_data[client].FF_Count, player_data[client].FF_Damage, player_data[client].Player_Deaths, player_data[client].Player_Kills, GetCurrentDate(true));
			SaveDatabaseLogMessage(sql_statement);
		}
	}
	else if (results.RowCount > 0 && DataType == MONTHLY_PLAYER_INFORMATION)
	{
		while (results.FetchRow())
		{
			has_value = true;
			int monthly_play_time = results.FetchInt(0);
			int monthly_max_play_time = results.FetchInt(1);
			int monthly_ff_count = results.FetchInt(2);
			int monthly_ff_damage = results.FetchInt(3);
			int monthly_deaths = results.FetchInt(4);
			int monthly_kills = results.FetchInt(5);
			int monthly_maps = results.FetchInt(6);
			
			if (g_hRecordLog.BoolValue)
			{
				char yearmonth[16] = {'\0'};
				GET_CURRENT_YEARMONTH(yearmonth);
				FormatEx(sql_statement, sizeof(sql_statement), "※成功获取到玩家：%N 的月度信息(%s)：游玩时长：%s，最大游玩时长：%s，黑枪次数：%d，黑枪伤害：%d，死亡数：%d，击杀数：%d，地图数：%d [%s]", 
				client, yearmonth, FormatDuration(monthly_play_time), FormatDuration(monthly_max_play_time), monthly_ff_count, monthly_ff_damage, monthly_deaths, monthly_kills, monthly_maps, GetCurrentDate(true));
				SaveDatabaseLogMessage(sql_statement);
			}
		}
	}
}
// 查询其他信息：数据库中是否有表，地图数据库中是否有需要自动添加的字段
void DQL_QueryOtherInformation(DBResultSet results, DQL_DATATYPE DataType)
{
	char sql_statement[SQL_STATEMENT_MAX_LENGTH] = {'\0'};
	if (DataType == QUERY_HAS_TABLES && results.RowCount == 0)
	{
		DML_ManageData(CREATE_TABLE_PLAYER_INFORMATION);
		DML_ManageData(CREATE_TABLE_PLAYER_MAPS);
		FormatEx(sql_statement, sizeof(sql_statement), DB_CREATE_TABLE_SUCCESS, DBNAME, TABLENAME_PLAYER_INFORMATION, TABLENAME_PLAYER_MAPS, GetCurrentDate(true));
		if (g_hRecordLog.BoolValue)
		{
			SaveDatabaseLogMessage(sql_statement);
		}
		PrintToServer(sql_statement);
	}
	else if (DataType == QUERY_HAS_MAPS)
	{
		char map_name[32] = {'\0'};
		GetCurrentMap(map_name, sizeof(map_name));
		FormatEx(sql_statement, sizeof(sql_statement), DML_ADD_MAPS, TABLENAME_PLAYER_MAPS, map_name, map_name);
		DML_ManageData(sql_statement);
		FormatEx(sql_statement, sizeof(sql_statement), DB_ADD_COLUMN_SUCCESS, TABLENAME_PLAYER_MAPS, map_name, GetCurrentDate(true));
		if (g_hRecordLog.BoolValue)
		{
			SaveDatabaseLogMessage(sql_statement);
		}
		PrintToServer(sql_statement);
	}
	else if (DataType == QUERY_HAS_MONTHLY_TABLES && results.RowCount == 0)
	{
		char yearmonth[16] = {'\0'}, create_info_table[1024] = {'\0'}, create_maps_table[1024] = {'\0'};
		GET_CURRENT_YEARMONTH(yearmonth);
		FormatEx(create_info_table, sizeof(create_info_table), CREATE_MONTHLY_TABLE_PLAYER_INFORMATION, yearmonth);
		FormatEx(create_maps_table, sizeof(create_maps_table), CREATE_MONTHLY_TABLE_PLAYER_MAPS, yearmonth);
		DML_ManageData(create_info_table);
		DML_ManageData(create_maps_table);
		FormatEx(sql_statement, sizeof(sql_statement), DB_CREATE_MONTHLY_TABLE_SUCCESS, DBNAME, yearmonth, yearmonth, GetCurrentDate(true));
		if (g_hRecordLog.BoolValue)
		{
			SaveDatabaseLogMessage(sql_statement);
		}
		PrintToServer(sql_statement);
	}
	else if (DataType == QUERY_HAS_MONTHLY_MAPS)
	{
		char map_name[32] = {'\0'}, yearmonth[16] = {'\0'};
		GetCurrentMap(map_name, sizeof(map_name));
		GET_CURRENT_YEARMONTH(yearmonth);
		FormatEx(sql_statement, sizeof(sql_statement), DML_ADD_MONTHLY_MAPS, yearmonth, map_name, map_name);
		DML_ManageData(sql_statement);
		FormatEx(sql_statement, sizeof(sql_statement), DB_ADD_MONTHLY_COLUMN_SUCCESS, yearmonth, map_name, GetCurrentDate(true));
		if (g_hRecordLog.BoolValue)
		{
			SaveDatabaseLogMessage(sql_statement);
		}
		PrintToServer(sql_statement);
	}
}
// 时长计算
char[] FormatDuration(int duration, bool english = false)
{
	char play_time[32] = {'\0'};
	if (duration < 60)
	{
		if (english)
		{
			FormatEx(play_time, sizeof(play_time), "%ds", duration);
		}
		else
		{
			FormatEx(play_time, sizeof(play_time), "%d秒", duration);
		}
	}
	else if (duration < 3600)
	{
		int minute = duration / 60;
		if (english)
		{
			FormatEx(play_time, sizeof(play_time), "%dmin%ds", minute, duration - (minute * 60));
		}
		else
		{
			FormatEx(play_time, sizeof(play_time), "%d分钟%d秒", minute, duration - (minute * 60));
		}
	}
	else
	{
		int hour = duration / 3600;
		int minute = duration / 60 % 60;
		int second = duration % 60;
		if (english)
		{
			FormatEx(play_time, sizeof(play_time), "%dh%dmin%ds", hour, minute, second);
		}
		else
		{
			FormatEx(play_time, sizeof(play_time), "%d小时%d分钟%d秒", hour, minute, second);
		}
	}
	return play_time;
}
// 输出当前时间
char[] GetCurrentDate(bool time = false)
{
	char current_date[32] = {'\0'};
	if (time)
	{
		FormatTime(current_date, sizeof(current_date), "%Y-%m-%d(%Hh%Mmin%Ss%p)", -1);
	}
	else
	{
		FormatTime(current_date, sizeof(current_date), "%Y-%m-%d", -1);
	}
	return current_date;
}

// 统计命令
public Action Cmd_Stats(int client, int args)
{
	if (IsValidSurvivor(client))
	{
		if (db_L4D2Server != null)
		{
			Draw_StatsMenu(client);
		}
		else
		{
			CPrintToChat(client, "{olive}[提示]：{lightgreen}未连接到数据库，无法读取玩家信息");
		}
	}
	else if (client == 0)
	{
		PrintToServer("统计指令：!stats 无法于服务端控制台使用");
		return Plugin_Handled;
	}
	else
	{
		CPrintToChat(client, INFO_SURVIVOR_ONLY);
	}
	return Plugin_Continue;
}

// 绘制统计信息菜单
public Action Draw_StatsMenu(int client)
{
	char info[128] = {'\0'}, steamID[32] = {'\0'};
	bool have_steamID = GetClientAuthId(client, AuthId_Steam2, steamID, sizeof(steamID));
	if (!have_steamID && strcmp(player_information[client].Player_SteamID, NULL_STRING) != 0)
	{
		strcopy(steamID, sizeof(steamID), player_information[client].Player_SteamID);
	}
	else if (!have_steamID)
	{
		KickClient(client, DB_STEAMID_ERROR_KICK);
		CPrintToChatAll(INFO_STEAMID_KICK, client);
		ResetLogInfos(false, client);
		return Plugin_Handled;
	}
	
	Panel StatsMenu = new Panel();
	FormatEx(info, sizeof(info), "玩家：%N", client);
	StatsMenu.DrawText(info);
	StatsMenu.DrawText("----------");
	
	int now_time = (GetTime() - player_information[client].Last_Login_Time) + player_data[client].Play_Time;
	int max_time = GetTime() - player_information[client].Last_Login_Time;
	max_time = (max_time > player_data[client].Max_Play_Time) ? max_time : player_data[client].Max_Play_Time;
	
	FormatEx(info, sizeof(info), "总游玩时间：%s", FormatDuration(now_time));
	StatsMenu.DrawText(info);
	FormatEx(info, sizeof(info), "最长游玩时间：%s", FormatDuration(max_time));
	StatsMenu.DrawText(info);
	FormatEx(info, sizeof(info), "游玩地图数量：%d", player_data[client].Total_Played_Maps);
	StatsMenu.DrawText(info);
	StatsMenu.DrawText("----------");
	FormatEx(info, sizeof(info), "黑枪次数：%d", player_data[client].FF_Count);
	StatsMenu.DrawText(info);
	FormatEx(info, sizeof(info), "黑枪总伤害：%d", player_data[client].FF_Damage);
	StatsMenu.DrawText(info);
	FormatEx(info, sizeof(info), "死亡次数：%d", player_data[client].Player_Deaths);
	StatsMenu.DrawText(info);
	FormatEx(info, sizeof(info), "击杀玩家次数：%d", player_data[client].Player_Kills);
	StatsMenu.DrawText(info);
	StatsMenu.DrawText("----------");
	StatsMenu.DrawItem("离开", ITEMDRAW_CONTROL);
	StatsMenu.Send(client, StatsMenuHandler, MENU_TIME_FOREVER);
	
	return Plugin_Continue;
}

public int StatsMenuHandler(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		if (item == 1)
		{
			delete menu;
		}
	}
	return 0;
}

// 黑枪统计事件
public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid")), attacker = GetClientOfUserId(event.GetInt("attacker")), damage = event.GetInt("dmg_health"), type = event.GetInt("type");
	if (IsValidSurvivor(victim) && IsValidSurvivor(attacker) && IsPlayerAlive(victim) && IsPlayerAlive(attacker) && attacker != victim)
	{
		// 使用 g_bBuckShot 记录是否为散弹枪造成的伤害，散弹枪为每个弹丸造成伤害，一次开枪可以造成多次伤害，判断伤害类型为散弹枪且 g_bBuckShot 为假时，设置为真，记录每个弹丸的伤害
		// 下一帧所有伤害造成完毕时，记录一次开枪次数
		if (g_bBuckShot[attacker])
		{
			player_data[attacker].FF_Damage += damage;
		}
		else
		{
			player_data[attacker].FF_Count += 1;
			player_data[attacker].FF_Damage += damage;
		}
		if (type & DMG_BUCKSHOT && !g_bBuckShot[attacker])
		{
			RequestFrame(NextFrame_Unmark, attacker);
			g_bBuckShot[attacker] = true;
		}
	}
}

void NextFrame_Unmark(int client)
{
	g_bBuckShot[client] = false;
}

// ====== 月度表相关函数 ======

// 更新月度表玩家名称
void UpdateMonthlyNames(char[] sql_statement, const char[] yearmonth, char[] steamID, char[] player_name)
{
	FormatEx(sql_statement, SQL_STATEMENT_MAX_LENGTH, DML_UPDATE_MONTHLY_PLAYER_INFO_AND_TIME, yearmonth, steamID, player_name);
	DML_ManageData(sql_statement);
	FormatEx(sql_statement, SQL_STATEMENT_MAX_LENGTH, DML_UPDATE_MONTHLY_PLAYER_INFO, yearmonth, steamID, player_name);
	DML_ManageData(sql_statement);
}

// 更新月度表玩家数据
void UpdateMonthlyPlayerData(int client, char[] steamID, const char[] yearmonth)
{
	char sql_statement[3 * SQL_STATEMENT_MAX_LENGTH] = {'\0'}, player_name[MAX_NAME_LENGTH] = {'\0'};
	int last_login_time = GetPlayTime(client, steamID);
	GetClientName(client, player_name, sizeof(player_name));
	if (last_login_time != -1)
	{
		UpdateMonthlyNames(sql_statement, yearmonth, steamID, player_name);
		int round_duration = GetTime() - last_login_time;
		FormatEx(sql_statement, sizeof(sql_statement), DML_UPDATE_MONTHLY_ALL_DATA
		, yearmonth, yearmonth, round_duration, round_duration, round_duration, 
		player_data[client].FF_Count, player_data[client].FF_Damage, player_data[client].Player_Deaths, player_data[client].Player_Kills, 
		player_data[client].Total_Played_Maps, steamID, steamID);
		DML_ManageData(sql_statement);
	}
}


