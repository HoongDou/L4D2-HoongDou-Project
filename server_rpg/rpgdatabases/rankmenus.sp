#pragma semicolon 1
#pragma newdecls required

#define INFO_DB_NULL "{olive}[提示]{default} 数据库未连接，无法使用排行榜功能"

#define SHOW_DELAY 0.3

// DQL查询语句定义
#define DQL_PLAYER_TOTAL_PLAYTIME "SELECT INFO.Player_Name, INFO.Total_Play_Time FROM %s AS INFO ORDER BY INFO.Total_Play_Time DESC LIMIT %d;"
#define DQL_MAX_PLAYTIME "SELECT INFO.Player_Name, INFO.Max_Pre_Play_Time FROM %s AS INFO ORDER BY INFO.Max_Pre_Play_Time DESC LIMIT %d;"
#define DQL_PLAYER_DEATHS "SELECT INFO.Player_Name, INFO.Player_Deaths FROM %s AS INFO WHERE INFO.Player_Deaths > 0 ORDER BY INFO.Player_Deaths DESC LIMIT %d;"
#define DQL_PLAYER_KILLS "SELECT INFO.Player_Name, INFO.Player_Kills FROM %s AS INFO WHERE INFO.Player_Kills > 0 ORDER BY INFO.Player_Kills DESC LIMIT %d;"
#define DQL_FF "SELECT INFO.Player_Name, INFO.FF_Count, INFO.FF_Damage FROM %s AS INFO WHERE INFO.FF_Damage > 0 ORDER BY INFO.FF_Damage DESC LIMIT %d;"
#define DQL_MAP_PLAYED "SELECT CP.Player_Name, CP.Total_Played_Maps FROM %s AS CP ORDER BY CP.Total_Played_Maps DESC LIMIT %d;"
#define DQL_PLAYER_ALLRANK "SELECT merge.no FROM ( SELECT info.STEAM_ID, info.%s, row_number() OVER (ORDER BY info.%s DESC) AS no FROM %s AS info ) AS merge WHERE merge.STEAM_ID = '%s' UNION ALL SELECT count(1) FROM %s;"

// 月度排行查询语句
#define DQL_MONTHLY_TOTAL_PLAYTIME "SELECT INFO.Player_Name, INFO.Total_Play_Time FROM player_information_%s AS INFO ORDER BY INFO.Total_Play_Time DESC LIMIT %d;"
#define DQL_MONTHLY_MAX_PLAYTIME "SELECT INFO.Player_Name, INFO.Max_Pre_Play_Time FROM player_information_%s AS INFO ORDER BY INFO.Max_Pre_Play_Time DESC LIMIT %d;"
#define DQL_MONTHLY_PLAYER_DEATHS "SELECT INFO.Player_Name, INFO.Player_Deaths FROM player_information_%s AS INFO WHERE INFO.Player_Deaths > 0 ORDER BY INFO.Player_Deaths DESC LIMIT %d;"
#define DQL_MONTHLY_PLAYER_KILLS "SELECT INFO.Player_Name, INFO.Player_Kills FROM player_information_%s AS INFO WHERE INFO.Player_Kills > 0 ORDER BY INFO.Player_Kills DESC LIMIT %d;"
#define DQL_MONTHLY_FF "SELECT INFO.Player_Name, INFO.FF_Count, INFO.FF_Damage FROM player_information_%s AS INFO WHERE INFO.FF_Damage > 0 ORDER BY INFO.FF_Damage DESC LIMIT %d;"
#define DQL_MONTHLY_MAP_PLAYED "SELECT CP.Player_Name, CP.Total_Played_Maps FROM player_campaign_%s AS CP ORDER BY CP.Total_Played_Maps DESC LIMIT %d;"
#define DQL_MONTHLY_PLAYER_ALLRANK "SELECT merge.no FROM ( SELECT info.STEAM_ID, info.%s, row_number() OVER (ORDER BY info.%s DESC) AS no FROM player_information_%s AS info ) AS merge WHERE merge.STEAM_ID = '%s' UNION ALL SELECT count(1) FROM player_information_%s;"

//#define DQL_AVAILABLE_MONTHLY_TABLES "SHOW TABLES LIKE 'player_information_%';"
// 用正则表达式表达
#define DQL_AVAILABLE_MONTHLY_TABLES "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME REGEXP '^player_information_[0-9]{6}$';"

// 序号文本
static const char SerialNum[][] = {
	"None", "第一", "前二名", "前三名", "前四名", "前五名", 
	"前六名", "前七名", "前八名", "前九名", "前十名", 
	"前十一名", "前十二名", "前十三名", "前十四名", "前十五名", 
	"前十六名", "前十七名", "前十八名", "前十九名", "前二十名"
};

// ConVars
ConVar g_hRankLimit;

// DataPacks
DataPack Rank_Packs[MAXPLAYERS + 1] = {null};
DataPack All_Rank_Packs[MAXPLAYERS + 1] = {null};
DataPack Available_Months_Packs[MAXPLAYERS + 1] = {null};

// 存储当前选择的月份
char g_sSelectedMonth[MAXPLAYERS + 1][16];

public void RankMenus_OnModuleStart()
{
	g_hRankLimit = CreateConVar("rank_ranklimit", "10", "默认一个 rankmenu 菜单显示多少条玩家排名信息", CVAR_FLAGS, true, 0.0);
	RegConsoleCmd("sm_rankmenu", Cmd_RankMenu, "打开玩家排行榜菜单");

	// 初始化选择的月份数组
	for (int i = 1; i <= MaxClients; i++)
	{
		g_sSelectedMonth[i][0] = '\0';
	}
}

public Action Cmd_RankMenu(int client, int args)
{
	if (IsValidClient(client))
	{
		if (db_L4D2Server != null)
		{
			Draw_RankMenu(client);
		}
		else
		{
			CPrintToChat(client, INFO_DB_NULL);
		}
	}
	else if (client == 0)
	{
		PrintToServer("玩家排行榜指令：!rankmenu 无法于服务端控制台使用");
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

// 绘制玩家排行榜菜单
public Action Draw_RankMenu(int client)
{
	Menu RankMenu = new Menu(RankMenuHandler);
	RankMenu.SetTitle("玩家信息排行榜");
	RankMenu.AddItem("Total_PlayTime", "总游玩时长排行榜");
	RankMenu.AddItem("Max_PlayTime", "单次最长游玩时长排行榜");
	RankMenu.AddItem("Player_Deaths", "死亡次数排行榜");
	RankMenu.AddItem("Player_Kills", "杀人魔排行榜");
	RankMenu.AddItem("Player_FF", "黑枪排行榜");
	RankMenu.AddItem("Player_Map_Played", "地图游玩数量排行榜");
	RankMenu.AddItem("Monthly_Ranks", "月度排行榜");
	RankMenu.ExitButton = true;
	RankMenu.Display(client, MENU_TIME_FOREVER);
	
	return Plugin_Continue;
}

// 绘制子排行榜菜单
public Action Draw_SubRankMenu(int client, DQL_DATATYPE Type)
{
	if (Rank_Packs[client] == null || All_Rank_Packs[client] == null)
	{
		return Plugin_Continue;
	}

	Rank_Packs[client].Reset();
	int row_count = Rank_Packs[client].ReadCell();
	row_count = (row_count < g_hRankLimit.IntValue) ? row_count : g_hRankLimit.IntValue;
	
	All_Rank_Packs[client].Reset();
	int my_rank = All_Rank_Packs[client].ReadCell();
	int total_rank = All_Rank_Packs[client].ReadCell();
	
	char info[128], player_name[MAX_NAME_LENGTH];
	Panel SubRankMenu = new Panel();

	char title_prefix[64] = "";
	char rank_scope[16] = "全服";

	// 判断是否为月度排行
	if (Type >= RANK_MONTHLY_TOTAL_PLAYTIME)
	{
		FormatEx(title_prefix, sizeof(title_prefix), "%c%c%c%c年%c%c月 ", 
			g_sSelectedMonth[client][0], g_sSelectedMonth[client][1], 
			g_sSelectedMonth[client][2], g_sSelectedMonth[client][3], 
			g_sSelectedMonth[client][4], g_sSelectedMonth[client][5]);
		strcopy(rank_scope, sizeof(rank_scope), "本月");
	}

	// 设置标题
	switch (Type)
	{
		case RANK_TOTAL_PLAYTIME, RANK_MONTHLY_TOTAL_PLAYTIME:
		{
			Format(info, sizeof(info), "%s游玩总时长排行：", title_prefix);
			SubRankMenu.SetTitle(info);
		}
		case RANK_MAX_PLAYTIME, RANK_MONTHLY_MAX_PLAYTIME:
		{
			Format(info, sizeof(info), "%s单次最长游玩时间排行：", title_prefix);
			SubRankMenu.SetTitle(info);
		}
		case RANK_PLAYER_DEATHS, RANK_MONTHLY_PLAYER_DEATHS:
		{
			Format(info, sizeof(info), "%s玩家死亡次数排行：", title_prefix);
			SubRankMenu.SetTitle(info);
		}
		case RANK_PLAYER_KILLS, RANK_MONTHLY_PLAYER_KILLS:
		{
			Format(info, sizeof(info), "%s击杀玩家次数排行：", title_prefix);
			SubRankMenu.SetTitle(info);
		}
		case RANK_MAP_PLAYED, RANK_MONTHLY_MAP_PLAYED:
		{
			Format(info, sizeof(info), "%s玩家地图游玩数量排行：", title_prefix);
			SubRankMenu.SetTitle(info);
		}
		case RANK_FF, RANK_MONTHLY_FF:
		{
			Format(info, sizeof(info), "%s玩家黑枪排行：", title_prefix);
			SubRankMenu.SetTitle(info);
		}
	}

	// 绘制排名信息
	SubRankMenu.DrawText("----------");
	FormatEx(info, sizeof(info), "我的排名：%d / %d", my_rank, total_rank);
	SubRankMenu.DrawText(info);
	SubRankMenu.DrawText("----------");
	FormatEx(info, sizeof(info), "%s%s", rank_scope, SerialNum[g_hRankLimit.IntValue]);
	SubRankMenu.DrawText(info);

	// 绘制排行榜数据
	if (Type == RANK_TOTAL_PLAYTIME || Type == RANK_MAX_PLAYTIME || 
		Type == RANK_MONTHLY_TOTAL_PLAYTIME || Type == RANK_MONTHLY_MAX_PLAYTIME)
	{
		char play_time[64];
		for (int i = 0; i < row_count; i++)
		{
			Rank_Packs[client].ReadString(player_name, sizeof(player_name));
			Rank_Packs[client].ReadString(play_time, sizeof(play_time));
			FormatEx(info, sizeof(info), "NO%d：%s(%s)", i + 1, player_name, play_time);
			SubRankMenu.DrawText(info);
		}
	}
	else if (Type == RANK_PLAYER_DEATHS || Type == RANK_PLAYER_KILLS || Type == RANK_MAP_PLAYED ||
			 Type == RANK_MONTHLY_PLAYER_DEATHS || Type == RANK_MONTHLY_PLAYER_KILLS || Type == RANK_MONTHLY_MAP_PLAYED)
	{
		for (int i = 0; i < row_count; i++)
		{
			Rank_Packs[client].ReadString(player_name, sizeof(player_name));
			int deaths_kills_maps = Rank_Packs[client].ReadCell();
			char unit[8];
			
			if (Type == RANK_MAP_PLAYED || Type == RANK_MONTHLY_MAP_PLAYED)
				strcopy(unit, sizeof(unit), "张");
			else
				strcopy(unit, sizeof(unit), "次");
				
			FormatEx(info, sizeof(info), "NO%d：%s(%d%s)", i + 1, player_name, deaths_kills_maps, unit);
			SubRankMenu.DrawText(info);
		}
	}
	else if (Type == RANK_FF || Type == RANK_MONTHLY_FF)
	{
		for (int i = 0; i < row_count; i++)
		{
			Rank_Packs[client].ReadString(player_name, sizeof(player_name));
			int player_ff_count = Rank_Packs[client].ReadCell();
			int player_ff_damage = Rank_Packs[client].ReadCell();
			FormatEx(info, sizeof(info), "NO%d：%s(%d次%d伤害)", i + 1, player_name, player_ff_count, player_ff_damage);
			SubRankMenu.DrawText(info);
		}
	}

	// 清理数据包
	delete Rank_Packs[client];
	Rank_Packs[client] = null;
	delete All_Rank_Packs[client];
	All_Rank_Packs[client] = null;
	
	SubRankMenu.DrawText("----------");
	SubRankMenu.DrawItem("返回", ITEMDRAW_CONTROL);
	SubRankMenu.DrawItem("离开", ITEMDRAW_CONTROL);
	SubRankMenu.Send(client, RankMenu_SubHandler, MENU_TIME_FOREVER);

	return Plugin_Continue;
}

// 排行榜主菜单处理
public int RankMenuHandler(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		char steamID[32], info[32], sql_statement[SQL_STATEMENT_MAX_LENGTH];
		bool have_steamID = GetClientAuthId(client, AuthId_Steam2, steamID, sizeof(steamID));
		
		if (!have_steamID && strcmp(player_information[client].Player_SteamID, "") != 0)
		{
			strcopy(steamID, sizeof(steamID), player_information[client].Player_SteamID);
		}
		else if (!have_steamID)
		{
			KickClient(client, DB_STEAMID_ERROR_KICK);
			CPrintToChatAll(INFO_STEAMID_KICK, client);
			ResetLogInfos(false, client);
			return 0;
		}
		
		menu.GetItem(item, info, sizeof(info));
		DataPack pack = new DataPack();
		pack.WriteCell(client);
		
		if (strcmp(info, "Total_PlayTime") == 0)
		{
			FormatEx(sql_statement, sizeof(sql_statement), DQL_PLAYER_ALLRANK, 
				"Total_Play_Time", "Total_Play_Time", TABLENAME_PLAYER_INFORMATION, steamID, TABLENAME_PLAYER_INFORMATION);
			DQL_PlayerRank(client, RANK_PLAYER_ALLRANK, sql_statement);
			
			FormatEx(sql_statement, sizeof(sql_statement), DQL_PLAYER_TOTAL_PLAYTIME, 
				TABLENAME_PLAYER_INFORMATION, g_hRankLimit.IntValue);
			DQL_PlayerRank(client, RANK_TOTAL_PLAYTIME, sql_statement);
			
			pack.WriteCell(RANK_TOTAL_PLAYTIME);
			CreateTimer(SHOW_DELAY, Timer_DrawRankMenu, pack);
		}
		else if (strcmp(info, "Max_PlayTime") == 0)
		{
			FormatEx(sql_statement, sizeof(sql_statement), DQL_PLAYER_ALLRANK, 
				"Max_Pre_Play_Time", "Max_Pre_Play_Time", TABLENAME_PLAYER_INFORMATION, steamID, TABLENAME_PLAYER_INFORMATION);
			DQL_PlayerRank(client, RANK_PLAYER_ALLRANK, sql_statement);
			
			FormatEx(sql_statement, sizeof(sql_statement), DQL_MAX_PLAYTIME, 
				TABLENAME_PLAYER_INFORMATION, g_hRankLimit.IntValue);
			DQL_PlayerRank(client, RANK_MAX_PLAYTIME, sql_statement);
			
			pack.WriteCell(RANK_MAX_PLAYTIME);
			CreateTimer(SHOW_DELAY, Timer_DrawRankMenu, pack);
		}
		else if (strcmp(info, "Player_Deaths") == 0)
		{
			FormatEx(sql_statement, sizeof(sql_statement), DQL_PLAYER_ALLRANK, 
				"Player_Deaths", "Player_Deaths", TABLENAME_PLAYER_INFORMATION, steamID, TABLENAME_PLAYER_INFORMATION);
			DQL_PlayerRank(client, RANK_PLAYER_ALLRANK, sql_statement);
			
			FormatEx(sql_statement, sizeof(sql_statement), DQL_PLAYER_DEATHS, 
				TABLENAME_PLAYER_INFORMATION, g_hRankLimit.IntValue);
			DQL_PlayerRank(client, RANK_PLAYER_DEATHS, sql_statement);
			
			pack.WriteCell(RANK_PLAYER_DEATHS);
			CreateTimer(SHOW_DELAY, Timer_DrawRankMenu, pack);
		}
		else if (strcmp(info, "Player_Kills") == 0)
		{
			FormatEx(sql_statement, sizeof(sql_statement), DQL_PLAYER_ALLRANK, 
				"Player_Kills", "Player_Kills", TABLENAME_PLAYER_INFORMATION, steamID, TABLENAME_PLAYER_INFORMATION);
			DQL_PlayerRank(client, RANK_PLAYER_ALLRANK, sql_statement);
			
			FormatEx(sql_statement, sizeof(sql_statement), DQL_PLAYER_KILLS, 
				TABLENAME_PLAYER_INFORMATION, g_hRankLimit.IntValue);
			DQL_PlayerRank(client, RANK_PLAYER_KILLS, sql_statement);
			
			pack.WriteCell(RANK_PLAYER_KILLS);
			CreateTimer(SHOW_DELAY, Timer_DrawRankMenu, pack);
		}
		else if (strcmp(info, "Player_Map_Played") == 0)
		{
			FormatEx(sql_statement, sizeof(sql_statement), DQL_PLAYER_ALLRANK, 
				"Total_Played_Maps", "Total_Played_Maps", TABLENAME_PLAYER_MAPS, steamID, TABLENAME_PLAYER_MAPS);
			DQL_PlayerRank(client, RANK_PLAYER_ALLRANK, sql_statement);
			
			FormatEx(sql_statement, sizeof(sql_statement), DQL_MAP_PLAYED, 
				TABLENAME_PLAYER_MAPS, g_hRankLimit.IntValue);
			DQL_PlayerRank(client, RANK_MAP_PLAYED, sql_statement);
			
			pack.WriteCell(RANK_MAP_PLAYED);
			CreateTimer(SHOW_DELAY, Timer_DrawRankMenu, pack);
		}
		else if (strcmp(info, "Player_FF") == 0)
		{
			FormatEx(sql_statement, sizeof(sql_statement), DQL_PLAYER_ALLRANK, 
				"FF_Damage", "FF_Damage", TABLENAME_PLAYER_INFORMATION, steamID, TABLENAME_PLAYER_INFORMATION);
			DQL_PlayerRank(client, RANK_PLAYER_ALLRANK, sql_statement);
			
			FormatEx(sql_statement, sizeof(sql_statement), DQL_FF, 
				TABLENAME_PLAYER_INFORMATION, g_hRankLimit.IntValue);
			DQL_PlayerRank(client, RANK_FF, sql_statement);
			
			pack.WriteCell(RANK_FF);
			CreateTimer(SHOW_DELAY, Timer_DrawRankMenu, pack);
		}
		else if (strcmp(info, "Monthly_Ranks") == 0)
		{
			Draw_MonthlyRankMenu(client);
			EmitSoundToClient(client, BUTTON_SOUND);
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
	
	return 0;
}

// 子菜单处理
public int RankMenu_SubHandler(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		if (item == 1) // 返回
		{
			if (g_sSelectedMonth[client][0] != '\0')
			{
				Draw_MonthlyRankTypeMenu(client);
			}
			else
			{
				Draw_RankMenu(client);
			}
			EmitSoundToClient(client, BUTTON_SOUND);
		}
		else if (item == 2) // 离开
		{
			delete menu;
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
	
	return 0;
}

// 延迟绘制排行榜
public Action Timer_DrawRankMenu(Handle timer, DataPack pack)
{
	if (pack != null)
	{
		pack.Reset();
		int client = pack.ReadCell();
		DQL_DATATYPE type = view_as<DQL_DATATYPE>(pack.ReadCell());
		Draw_SubRankMenu(client, type);
		delete pack;
	}
	
	return Plugin_Continue;
}

// 执行排行查询
void DQL_PlayerRank(int client, DQL_DATATYPE Type, const char[] information)
{
	if (db_L4D2Server != null)
	{
		DataPack pack = new DataPack();
		pack.WriteCell(client);
		pack.WriteCell(Type);
		
		switch (Type)
		{
			case RANK_PLAYER_ALLRANK, RANK_MONTHLY_PLAYER_ALLRANK:
			{
				db_L4D2Server.Query(DQL_PlayerAllRankCallBack, information, pack);
			}
			default:
			{
				db_L4D2Server.Query(DQL_PlayerRankCallBack, information, pack);
			}
		}
	}
}

// 玩家总排名回调
void DQL_PlayerAllRankCallBack(Database db, DBResultSet results, const char[] error, DataPack pack = null)
{
	if (db != null && results != null && strcmp(error, "") == 0)
	{
		if (pack != null)
		{
			pack.Reset();
			int client = pack.ReadCell();
			delete pack;
			
			DataPack client_pack = new DataPack();
			while (results.FetchRow())
			{
				int my_rank = results.FetchInt(0);
				client_pack.WriteCell(my_rank);
			}
			All_Rank_Packs[client] = client_pack;
		}
	}
	else if (db == null)
	{
		PrintToServer(DB_CONNECT_INVALID_HANDLE, DBNAME);
	}
	else if (strcmp(error, "") != 0)
	{
		PrintToServer(DB_MANAGE_ERROR, DBNAME, error);
	}
}

// 玩家排行数据回调
void DQL_PlayerRankCallBack(Database db, DBResultSet results, const char[] error, DataPack pack = null)
{
	if (db != null && results != null && strcmp(error, "") == 0)
	{
		if (pack != null)
		{
			pack.Reset();
			int client = pack.ReadCell();
			DQL_DATATYPE type = view_as<DQL_DATATYPE>(pack.ReadCell());
			delete pack;
			
			DataPack client_pack = new DataPack();
			char player_name[MAX_NAME_LENGTH];
			client_pack.WriteCell(results.RowCount);
			
			// 播放时长类
			if (type == RANK_TOTAL_PLAYTIME || type == RANK_MAX_PLAYTIME || 
				type == RANK_MONTHLY_TOTAL_PLAYTIME || type == RANK_MONTHLY_MAX_PLAYTIME)
			{
				while (results.FetchRow())
				{
					results.FetchString(0, player_name, sizeof(player_name));
					GetClientFixedName(player_name, sizeof(player_name));
					client_pack.WriteString(player_name);
					int play_time = results.FetchInt(1);
					client_pack.WriteString(FormatDuration(play_time, true));
				}
				Rank_Packs[client] = client_pack;
			}
			// 死亡/击杀/地图类
			else if (type == RANK_PLAYER_DEATHS || type == RANK_PLAYER_KILLS || type == RANK_MAP_PLAYED || 
					 type == RANK_MONTHLY_PLAYER_DEATHS || type == RANK_MONTHLY_PLAYER_KILLS || type == RANK_MONTHLY_MAP_PLAYED)
			{
				while (results.FetchRow())
				{
					results.FetchString(0, player_name, sizeof(player_name));
					GetClientFixedName(player_name, sizeof(player_name));
					client_pack.WriteString(player_name);
					int deaths_kills_maps = results.FetchInt(1);
					client_pack.WriteCell(deaths_kills_maps);
				}
				Rank_Packs[client] = client_pack;
			}
			// 黑枪类（单独处理，避免穿透）
			else if (type == RANK_FF || type == RANK_MONTHLY_FF)
			{
				while (results.FetchRow())
				{
					results.FetchString(0, player_name, sizeof(player_name));
					GetClientFixedName(player_name, sizeof(player_name));
					client_pack.WriteString(player_name);
					int player_ff_count = results.FetchInt(1);
					client_pack.WriteCell(player_ff_count);
					int player_ff_damage = results.FetchInt(2);
					client_pack.WriteCell(player_ff_damage);
				}
				Rank_Packs[client] = client_pack;
			}
			// 可用月份查询
			else if (type == RANK_QUERY_AVAILABLE_MONTHS)
			{
				DataPack months_pack = new DataPack();
				int count = 0;
				char table_name[64], yearmonth[16];
				char current_month[16];
				GET_CURRENT_YEARMONTH(current_month);

				PrintToServer("[DEBUG] 当前月份: %s", current_month);
				PrintToServer("[DEBUG] 开始遍历表名...");

				while (results.FetchRow())
				{
					results.FetchString(0, table_name, sizeof(table_name));
					PrintToServer("[DEBUG] 找到表: %s", table_name);

					//strcopy(yearmonth, sizeof(yearmonth), table_name);
					//ReplaceString(yearmonth, sizeof(yearmonth), "player_information_", "");
    				// 检查是否以 "player_information_" 开头
    				if (strncmp(table_name, "player_information_", 19) == 0)
    				{
        				// 从第19个字符开始复制（跳过 "player_information_"）
        				strcopy(yearmonth, sizeof(yearmonth), table_name[19]);
						PrintToServer("[DEBUG] 提取的年月: %s, 长度: %d, 是数字: %d", yearmonth, strlen(yearmonth), IsNumericString(yearmonth));

						if (strlen(yearmonth) == 6 && IsNumericString(yearmonth) && strcmp(yearmonth, current_month) != 0)
        				{
            				months_pack.WriteString(yearmonth);
            				count++;
            				PrintToServer("[DEBUG] 添加有效月份: %s", yearmonth);
        				}
					}
				}
				PrintToServer("[DEBUG] 总共找到 %d 个有效月份", count);

				DataPack final_pack = new DataPack();
				final_pack.WriteCell(count);
				months_pack.Reset();
				for (int i = 0; i < count; i++)
				{
					months_pack.ReadString(yearmonth, sizeof(yearmonth));
					final_pack.WriteString(yearmonth);
				}
				delete months_pack;

				Available_Months_Packs[client] = final_pack;
				RequestFrame(Frame_DrawAvailableMonthsMenu, GetClientUserId(client));
			}
		}
	}
	else if (db == null)
	{
		PrintToServer(DB_CONNECT_INVALID_HANDLE, DBNAME);
	}
	else if (strcmp(error, "") != 0)
	{
		PrintToServer(DB_MANAGE_ERROR, DBNAME, error);
	}
}

// 修正玩家名称显示
void GetClientFixedName(char[] name, int length)
{
	if (name[0] == '[')
	{
		char temp[MAX_NAME_LENGTH];
		strcopy(temp, sizeof(temp), name);
		temp[sizeof(temp)-2] = 0;
		strcopy(name[1], length-1, temp);
		name[0] = ' ';
	}
	
	if (strlen(name) > 18)
	{
		name[15] = name[16] = name[17] = '.';
		name[18] = 0;
	}
}

// 绘制月度排行主菜单
public Action Draw_MonthlyRankMenu(int client)
{
	g_sSelectedMonth[client][0] = '\0';

	Menu MonthlyRankMenu = new Menu(MonthlyRankMenuHandler);
	MonthlyRankMenu.SetTitle("月度排行榜");
	MonthlyRankMenu.AddItem("Current_Month", "当前月度排行");
	MonthlyRankMenu.AddItem("History_Month", "历史月度排行");
	MonthlyRankMenu.ExitBackButton = true;
	MonthlyRankMenu.Display(client, MENU_TIME_FOREVER);
	
	return Plugin_Continue;
}

// 月度排行菜单处理
public int MonthlyRankMenuHandler(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(item, info, sizeof(info));
		
		if (strcmp(info, "Current_Month") == 0)
		{
			char yearmonth[16];
			GET_CURRENT_YEARMONTH(yearmonth);
			strcopy(g_sSelectedMonth[client], sizeof(g_sSelectedMonth), yearmonth);
			Draw_MonthlyRankTypeMenu(client);
			EmitSoundToClient(client, BUTTON_SOUND);
		}
		else if (strcmp(info, "History_Month") == 0)
		{
			char sql_statement[SQL_STATEMENT_MAX_LENGTH];
			FormatEx(sql_statement, sizeof(sql_statement), DQL_AVAILABLE_MONTHLY_TABLES);
			DQL_PlayerRank(client, RANK_QUERY_AVAILABLE_MONTHS, sql_statement);
			EmitSoundToClient(client, BUTTON_SOUND);
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if (item == MenuCancel_ExitBack)
		{
			Draw_RankMenu(client);
			EmitSoundToClient(client, BUTTON_SOUND);
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
	
	return 0;
}


// 绘制可用月份选择菜单
public Action Draw_AvailableMonthsMenu(int client)
{
   if (Available_Months_Packs[client] == null)
   {
  	CPrintToChat(client, "{olive}[提示]{default} 暂无历史月度数据");
  	Draw_MonthlyRankMenu(client);
  	return Plugin_Continue;
   }
   
   Available_Months_Packs[client].Reset();
   int count = Available_Months_Packs[client].ReadCell();
   
   if (count == 0)
   {
  	CPrintToChat(client, "{olive}[提示]{default} 暂无历史月度数据");
  	Draw_MonthlyRankMenu(client);
  	delete Available_Months_Packs[client];
  	Available_Months_Packs[client] = null;
  	return Plugin_Continue;
   }
   
   Menu AvailableMonthsMenu = new Menu(AvailableMonthsMenuHandler);
   AvailableMonthsMenu.SetTitle("选择查询月份");
   
   char yearmonth[16], display[32];
   
   for (int i = 0; i < count; i++)
   {
  	Available_Months_Packs[client].ReadString(yearmonth, sizeof(yearmonth));
  	// 格式化显示: 202510 -> 2025年10月
  	FormatEx(display, sizeof(display), "%c%c%c%c年%c%c月", 
 		yearmonth[0], yearmonth[1], yearmonth[2], yearmonth[3], yearmonth[4], yearmonth[5]);
  	AvailableMonthsMenu.AddItem(yearmonth, display);
   }
   
   delete Available_Months_Packs[client];
   Available_Months_Packs[client] = null;
   
   AvailableMonthsMenu.ExitBackButton = true;
   AvailableMonthsMenu.Display(client, MENU_TIME_FOREVER);
   return Plugin_Continue;
}

// 可用月份菜单处理函数
public int AvailableMonthsMenuHandler(Menu menu, MenuAction action, int client, int item)
{
   if (action == MenuAction_Select)
   {
  	char yearmonth[16];
  	menu.GetItem(item, yearmonth, sizeof(yearmonth));
  	strcopy(g_sSelectedMonth[client], sizeof(g_sSelectedMonth), yearmonth);
  	Draw_MonthlyRankTypeMenu(client);
  	EmitSoundToClient(client, BUTTON_SOUND);
   }
   else if (action == MenuAction_Cancel)
   {
  	if (item == MenuCancel_ExitBack)
  	{
 		Draw_MonthlyRankMenu(client);
 		EmitSoundToClient(client, BUTTON_SOUND);
  	}
   }
   else if (action == MenuAction_End)
   {
  	delete menu;
   }
   return 0;
}

// 绘制月度排行类型选择菜单
public Action Draw_MonthlyRankTypeMenu(int client)
{
   char title[64], display_month[32];
   // 格式化月份显示
   FormatEx(display_month, sizeof(display_month), "%c%c%c%c年%c%c月", 
  	g_sSelectedMonth[client][0], g_sSelectedMonth[client][1], 
  	g_sSelectedMonth[client][2], g_sSelectedMonth[client][3], 
  	g_sSelectedMonth[client][4], g_sSelectedMonth[client][5]);
   FormatEx(title, sizeof(title), "%s 排行榜", display_month);
   
   Menu MonthlyTypeMenu = new Menu(MonthlyRankTypeMenuHandler);
   MonthlyTypeMenu.SetTitle(title);
   MonthlyTypeMenu.AddItem("Monthly_Total_PlayTime", "游玩总时长排行");
   MonthlyTypeMenu.AddItem("Monthly_Max_PlayTime", "单次最长游玩时长排行");
   MonthlyTypeMenu.AddItem("Monthly_Player_Deaths", "死亡次数排行");
   MonthlyTypeMenu.AddItem("Monthly_Player_Kills", "杀人魔排行");
   MonthlyTypeMenu.AddItem("Monthly_Player_FF", "黑枪排行");
   MonthlyTypeMenu.AddItem("Monthly_Player_Map_Played", "地图游玩数量排行");
   MonthlyTypeMenu.ExitBackButton = true;
   MonthlyTypeMenu.Display(client, MENU_TIME_FOREVER);
   return Plugin_Continue;
}

// 月度排行类型菜单处理函数
public int MonthlyRankTypeMenuHandler(Menu menu, MenuAction action, int client, int item)
{
   if (action == MenuAction_Select)
   {
  	char steamID[32], info[64], sql_statement[SQL_STATEMENT_MAX_LENGTH];
  	bool have_steamID = GetClientAuthId(client, AuthId_Steam2, steamID, sizeof(steamID));
  	if (!have_steamID && strcmp(player_information[client].Player_SteamID, "") != 0)
  	{
 		strcopy(steamID, sizeof(steamID), player_information[client].Player_SteamID);
  	}
  	else if (!have_steamID)
  	{
 		KickClient(client, DB_STEAMID_ERROR_KICK);
 		CPrintToChatAll(INFO_STEAMID_KICK, client);
 		ResetLogInfos(false, client);
 		return 0;
  	}
  	
  	menu.GetItem(item, info, sizeof(info));
  	DataPack pack = new DataPack();
  	pack.WriteCell(client);
  	
  	char yearmonth[16];
  	strcopy(yearmonth, sizeof(yearmonth), g_sSelectedMonth[client]);
  	
  	if (strcmp(info, "Monthly_Total_PlayTime") == 0)
  	{
 		FormatEx(sql_statement, sizeof(sql_statement), DQL_MONTHLY_PLAYER_ALLRANK, "Total_Play_Time", "Total_Play_Time", yearmonth, steamID, yearmonth);
 		DQL_PlayerRank(client, RANK_MONTHLY_PLAYER_ALLRANK, sql_statement);
 		FormatEx(sql_statement, sizeof(sql_statement), DQL_MONTHLY_TOTAL_PLAYTIME, yearmonth, g_hRankLimit.IntValue);
 		DQL_PlayerRank(client, RANK_MONTHLY_TOTAL_PLAYTIME, sql_statement);
 		pack.WriteCell(RANK_MONTHLY_TOTAL_PLAYTIME);
 		CreateTimer(SHOW_DELAY, Timer_DrawRankMenu, pack);
  	}
  	else if (strcmp(info, "Monthly_Max_PlayTime") == 0)
  	{
 		FormatEx(sql_statement, sizeof(sql_statement), DQL_MONTHLY_PLAYER_ALLRANK, "Max_Pre_Play_Time", "Max_Pre_Play_Time", yearmonth, steamID, yearmonth);
 		DQL_PlayerRank(client, RANK_MONTHLY_PLAYER_ALLRANK, sql_statement);
 		FormatEx(sql_statement, sizeof(sql_statement), DQL_MONTHLY_MAX_PLAYTIME, yearmonth, g_hRankLimit.IntValue);
 		DQL_PlayerRank(client, RANK_MONTHLY_MAX_PLAYTIME, sql_statement);
 		pack.WriteCell(RANK_MONTHLY_MAX_PLAYTIME);
 		CreateTimer(SHOW_DELAY, Timer_DrawRankMenu, pack);
  	}
  	else if (strcmp(info, "Monthly_Player_Deaths") == 0)
  	{
 		FormatEx(sql_statement, sizeof(sql_statement), DQL_MONTHLY_PLAYER_ALLRANK, "Player_Deaths", "Player_Deaths", yearmonth, steamID, yearmonth);
 		DQL_PlayerRank(client, RANK_MONTHLY_PLAYER_ALLRANK, sql_statement);
 		FormatEx(sql_statement, sizeof(sql_statement), DQL_MONTHLY_PLAYER_DEATHS, yearmonth, g_hRankLimit.IntValue);
 		DQL_PlayerRank(client, RANK_MONTHLY_PLAYER_DEATHS, sql_statement);
 		pack.WriteCell(RANK_MONTHLY_PLAYER_DEATHS);
 		CreateTimer(SHOW_DELAY, Timer_DrawRankMenu, pack);
  	}
  	else if (strcmp(info, "Monthly_Player_Kills") == 0)
  	{
 		FormatEx(sql_statement, sizeof(sql_statement), DQL_MONTHLY_PLAYER_ALLRANK, "Player_Kills", "Player_Kills", yearmonth, steamID, yearmonth);
 		DQL_PlayerRank(client, RANK_MONTHLY_PLAYER_ALLRANK, sql_statement);
 		FormatEx(sql_statement, sizeof(sql_statement), DQL_MONTHLY_PLAYER_KILLS, yearmonth, g_hRankLimit.IntValue);
 		DQL_PlayerRank(client, RANK_MONTHLY_PLAYER_KILLS, sql_statement);
 		pack.WriteCell(RANK_MONTHLY_PLAYER_KILLS);
 		CreateTimer(SHOW_DELAY, Timer_DrawRankMenu, pack);
  	}
  	else if (strcmp(info, "Monthly_Player_FF") == 0)
  	{
 		FormatEx(sql_statement, sizeof(sql_statement), DQL_MONTHLY_PLAYER_ALLRANK, "FF_Damage", "FF_Damage", yearmonth, steamID, yearmonth);
 		DQL_PlayerRank(client, RANK_MONTHLY_PLAYER_ALLRANK, sql_statement);
 		FormatEx(sql_statement, sizeof(sql_statement), DQL_MONTHLY_FF, yearmonth, g_hRankLimit.IntValue);
 		DQL_PlayerRank(client, RANK_MONTHLY_FF, sql_statement);
 		pack.WriteCell(RANK_MONTHLY_FF);
 		CreateTimer(SHOW_DELAY, Timer_DrawRankMenu, pack);
  	}
  	else if (strcmp(info, "Monthly_Player_Map_Played") == 0)
  	{
 		FormatEx(sql_statement, sizeof(sql_statement), "SELECT merge.no FROM ( SELECT info.STEAM_ID, info.Total_Played_Maps, row_number() OVER (ORDER BY info.Total_Played_Maps DESC) AS no FROM player_campaign_%s AS info ) \
AS merge WHERE merge.STEAM_ID = '%s' UNION ALL SELECT count(1) FROM player_campaign_%s;", yearmonth, steamID, yearmonth);
 		DQL_PlayerRank(client, RANK_MONTHLY_PLAYER_ALLRANK, sql_statement);
 		FormatEx(sql_statement, sizeof(sql_statement), DQL_MONTHLY_MAP_PLAYED, yearmonth, g_hRankLimit.IntValue);
 		DQL_PlayerRank(client, RANK_MONTHLY_MAP_PLAYED, sql_statement);
 		pack.WriteCell(RANK_MONTHLY_MAP_PLAYED);
 		CreateTimer(SHOW_DELAY, Timer_DrawRankMenu, pack);
  	}
  	
  	EmitSoundToClient(client, BUTTON_SOUND);
   }
   else if (action == MenuAction_Cancel)
   {
  	if (item == MenuCancel_ExitBack)
  	{
 		Draw_MonthlyRankMenu(client);
 		EmitSoundToClient(client, BUTTON_SOUND);
  	}
   }
   else if (action == MenuAction_End)
   {
  	delete menu;
   }
   return 0;
}

// 检查字符串是否全为数字
bool IsNumericString(const char[] str)
{
   int len = strlen(str);
   if (len == 0) return false;
   
   for (int i = 0; i < len; i++)
   {
  	if (str[i] < '0' || str[i] > '9')
 		return false;
   }
   return true;
}

// 使用 RequestFrame 替代 Timer
void Frame_DrawAvailableMonthsMenu(any data)
{
   int client = GetClientOfUserId(data);
	if (IsValidClient(client))
	{
		Draw_AvailableMonthsMenu(client);
	}
}
