#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <colors>
#include <left4dhooks>

#define PLUGIN_NAME				"Tank Data Infomation"
#define PLUGIN_AUTHOR			"HoongDou"
#define PLUGIN_DESCRIPTION		"Tank Data Infomation"
#define PLUGIN_VERSION			"1.8"
#define PLUGIN_URL				""


enum struct esData {
	int lastTankHealth;
	int totalTankDmg;
	int totalTankAliveTime[MAXPLAYERS + 1];
	int tankDmg[MAXPLAYERS + 1];
	int tankClaw[MAXPLAYERS + 1];
	int tankRock[MAXPLAYERS + 1];
	int tankHittable[MAXPLAYERS + 1];



	void CleanTank() {
		this.totalTankDmg = 0;
		this.lastTankHealth = 0;

		for (int i = 1; i <= MaxClients; i++) {
			this.tankDmg[i] = 0;
			this.tankClaw[i] = 0;
			this.tankRock[i] = 0;
			this.tankHittable[i] = 0;
			this.totalTankAliveTime[i] = 0;
		}
	}
}

esData
	g_esData[MAXPLAYERS + 1];

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart() {
	HookEvent("round_end",					Event_RoundEnd,			EventHookMode_PostNoCopy);
	HookEvent("player_hurt",				Event_PlayerHurt);
	HookEvent("player_death",				Event_PlayerDeath,		EventHookMode_Pre);
	HookEvent("tank_spawn",					Event_TankSpawn);
	HookEvent("player_incapacitated_start",	Event_PlayerIncapacitatedStart);
	
	RegConsoleCmd("sm_tankdata", cmdShowTankInfo, "Show Tank Infomation");

}

Action cmdShowTankInfo(int client, int args) {
	if (!client || !IsClientInGame(client))
		return Plugin_Handled;

	PrintTankStatistics(client);
	return Plugin_Handled;
}


public void OnClientDisconnect(int client) {
	g_esData[client].CleanTank();

	for (int i = 1; i <= MaxClients; i++) {
		g_esData[i].tankDmg[client] = 0;
		g_esData[i].tankClaw[client] = 0;
		g_esData[i].tankRock[client] = 0;
		g_esData[i].tankHittable[client] = 0;
		g_esData[i].totalTankAliveTime[client] = 0;
	}
}

public void OnMapEnd() {
	ClearTankData();
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
	int totalClaw = 0;
	int totalRock = 0;
	int totalHittable = 0;
	int tank = -1;

	// 查找当前存活的 Tank
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == 3 && GetEntProp(i, Prop_Send, "m_zombieClass") == 8 && IsPlayerAlive(i)) {
			tank = i;
		}
	}

	if (tank != -1) {
		// 统计吃拳次数、吃饼次数和吃铁次数
		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i) && (!IsFakeClient(i) || GetClientTeam(i) == 2) && IsActive(tank, i)) {
				totalClaw += g_esData[tank].tankClaw[i];
				totalRock += g_esData[tank].tankRock[i];
				totalHittable += g_esData[tank].tankHittable[i];
			}
		}
		// 获取坦克的剩余血量
		int ilastTankHealth = g_esData[tank].lastTankHealth;

		// 输出汇总信息
		CPrintToChatAll("{blue}Tank {default}still have {green}%d {default}health! Give: {olive}%d{default} Punch(s), {olive}%d{default} Rock(s), {olive}%d{default} Entities",ilastTankHealth,totalClaw,totalRock,totalHittable);
		PrintTankDetailsStatistics(tank);
	}

	OnMapEnd();
}



void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast) {
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (!attacker || !IsClientInGame(attacker))
		return;

	int victim = GetClientOfUserId(event.GetInt("userid"));
	if (!victim || victim == attacker || !IsClientInGame(victim))
		return;

	switch (GetClientTeam(victim)) {
		case 2: {
			switch (GetClientTeam(attacker)) {
				case 3: {
					if (GetEntProp(attacker, Prop_Send, "m_zombieClass") == 8) {
						char weapon[32];
						event.GetString("weapon", weapon, sizeof weapon);
						if (strcmp(weapon, "tank_claw") == 0)
							g_esData[attacker].tankClaw[victim]++;
						else if (strcmp(weapon, "tank_rock") == 0)
							g_esData[attacker].tankRock[victim]++;
						else
							g_esData[attacker].tankHittable[victim]++;
					}
				}
			}
		}
		
		case 3: {
			if (GetClientTeam(attacker) == 2) {
				int dmg = event.GetInt("dmg_health");
				switch (GetEntProp(victim, Prop_Send, "m_zombieClass")) {
		
					case 8: {
						if (!GetEntProp(victim, Prop_Send, "m_isIncapacitated")) {
							g_esData[victim].totalTankDmg += dmg;
							g_esData[victim].tankDmg[attacker] += dmg;

							g_esData[victim].lastTankHealth = event.GetInt("health");
						}
					}
				}
			}
		}
	}
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	int victim = GetClientOfUserId(event.GetInt("userid"));
	if (!victim || !IsClientInGame(victim) || GetClientTeam(victim) != 3)
		return;

	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int class = GetEntProp(victim, Prop_Send, "m_zombieClass");
	if (class == 8) {
		g_esData[victim].totalTankDmg += g_esData[victim].lastTankHealth;
		g_esData[victim].tankDmg[attacker] += g_esData[victim].lastTankHealth;

		PrintTankStatistics(victim);
	}

	if (!attacker || !IsClientInGame(attacker) || GetClientTeam(attacker) != 2)
		return;

}


void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client && IsClientInGame(client))
		g_esData[client].CleanTank();
		CreateTimer(1.0,Event_TankAliveTime_save,GetClientUserId(client),TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
}

void Event_TankAliveTime_save(Handle timer, any userid) {
	int client = GetClientOfUserId(userid);
	if (client && IsClientInGame(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 8 && IsPlayerAlive(client)) {
		g_esData[client].totalTankAliveTime[client]++;
	} else {
		KillTimer(timer);
	}
}

void Event_PlayerIncapacitatedStart(Event event, const char[] name, bool dontBroadcast) {
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (!attacker || !IsClientInGame(attacker) || GetClientTeam(attacker) != 3 || GetEntProp(attacker, Prop_Send, "m_zombieClass") != 8)
		return;

	int victim = GetClientOfUserId(event.GetInt("userid"));
	if (!victim || !IsClientInGame(victim) || GetClientTeam(victim) != 2)
		return;
	
	char weapon[32];
	event.GetString("weapon", weapon, sizeof weapon);
	if (strcmp(weapon, "tank_claw") == 0)
		g_esData[attacker].tankClaw[victim]++;
	else if (strcmp(weapon, "tank_rock") == 0)
		g_esData[attacker].tankRock[victim]++;
	else
		g_esData[attacker].tankHittable[victim]++;
}



void PrintTankStatistics(int tank) {
	if (g_esData[tank].totalTankDmg <= 0)
		return;

	int totalClaw = 0;
	int totalRock = 0;
	int totalHittable = 0;
	int totalAliveTime = g_esData[tank].totalTankAliveTime[tank];

	// 统计坦克生存时间、吃拳次数、吃饼次数和吃铁次数
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && (!IsFakeClient(i) || GetClientTeam(i) == 2) && IsActive(tank, i)) {
			totalClaw += g_esData[tank].tankClaw[i];
			totalRock += g_esData[tank].tankRock[i];
			totalHittable += g_esData[tank].tankHittable[i];
			totalAliveTime += g_esData[tank].totalTankAliveTime[i];
		}
	}

	// 输出汇总信息
	CPrintToChatAll("{default}[{green}!{default}] {blue}Tank {default}Survived {olive}%d{default} second(s) with: {olive}%d{default} Punch(s), {olive}%d{default} Rock(s), {olive}%d{default} Entities", totalAliveTime, totalClaw, totalRock, totalHittable);
	// 调用详细统计信息输出方法
	PrintTankDetailsStatistics(tank);
}

void PrintTankDetailsStatistics(int tank){
	// 创建 ArrayList 存储客户端数据
	ArrayList aClients = new ArrayList(2);

	int i = 1;
	for (; i <= MaxClients; i++) {
		if (IsClientInGame(i) && (!IsFakeClient(i) || GetClientTeam(i) == 2) && IsActive(tank, i))
			aClients.Set(aClients.Push(g_esData[tank].tankDmg[i]), i, 1);
	}

	int length = aClients.Length;
	if (!length) {
		delete aClients;
		return;
	}

	aClients.Sort(Sort_Descending, Sort_Integer);

	char str[12];
	int damage = aClients.Get(0, 0);
	int dmgLen = IntToString(damage, str, sizeof str);

	int count;
	int client;
	int dataSort[MAXPLAYERS + 1];
	for (i = 0; i < length; i++) {
		client = aClients.Get(i, 1);
		dataSort[count++] = g_esData[tank].tankClaw[client];
	}

	SortIntegers(dataSort, count, Sort_Descending);
	int clawLen = !count ? 1 : IntToString(dataSort[0], str, sizeof str);

	count = 0;
	for (i = 0; i < length; i++) {
		client = aClients.Get(i, 1);
		damage = aClients.Get(i, 0);
		int percent = RoundToNearest(float(damage) / float(g_esData[tank].totalTankDmg) * 100.0);
		dataSort[count++] = percent;
	}

	SortIntegers(dataSort, count, Sort_Descending);
	int percLen = !count ? 1 : IntToString(dataSort[0], str, sizeof str);

	count = 0;
	for (i = 0; i < length; i++) {
		client = aClients.Get(i, 1);
		dataSort[count++] = g_esData[tank].tankRock[client];
	}

	SortIntegers(dataSort, count, Sort_Descending);
	int rockLen = !count ? 1 : IntToString(dataSort[0], str, sizeof str);

	count = 0;
	for (i = 0; i < length; i++) {
		client = aClients.Get(i, 1);
		dataSort[count++] = g_esData[tank].tankHittable[client];
	}

	SortIntegers(dataSort, count, Sort_Descending);
	int hitLen = !count ? 1 : IntToString(dataSort[0], str, sizeof str);

	char name[MAX_NAME_LENGTH];
	FormatEx(name, sizeof name, "[%s] %N", IsFakeClient(tank) ? "AI" : "PZ", tank);
	CPrintToChatAll("{default}[{green}!{default}] {blue}Damage {default}dealt to {default}[{olive}%s{default}] {blue}%N {default}%d", IsFakeClient(tank) ? "AI" : "PZ", tank, g_esData[tank].totalTankDmg);

	int len;
	int numSpace;
	char buffer[254];
	for (i = 0; i < length; i++) {
		client = aClients.Get(i, 1);
		damage = aClients.Get(i, 0);
		int percent = RoundToNearest(float(damage) / float(g_esData[tank].totalTankDmg) * 100.0);

		strcopy(buffer, sizeof buffer, "{blue}[");
		numSpace = dmgLen - IntToString(damage, str, sizeof str);
		AppendSpaceChar(buffer, sizeof buffer, numSpace);
		len = strlen(buffer);
		Format(buffer[len], sizeof buffer - len, "{default}%s", str);
		AppendSpaceChar(buffer, sizeof buffer, numSpace);

		len = strlen(buffer);
		strcopy(buffer[len], sizeof buffer - len, "{blue}]{default}(");
		numSpace = percLen - IntToString(percent, str, sizeof str);
		AppendSpaceChar(buffer, sizeof buffer, numSpace);
		len = strlen(buffer);
		Format(buffer[len], sizeof buffer - len, "{olive}%s%%", str);
		AppendSpaceChar(buffer, sizeof buffer, numSpace);

		len = strlen(buffer);
		strcopy(buffer[len], sizeof buffer - len, "{default}) ");
		numSpace = clawLen - IntToString(g_esData[tank].tankClaw[client], str, sizeof str);
		AppendSpaceChar(buffer, sizeof buffer, numSpace);
		len = strlen(buffer);
		Format(buffer[len], sizeof buffer - len, "{olive}%s {default}Punch(s) ", str);
		AppendSpaceChar(buffer, sizeof buffer, numSpace);

		len = strlen(buffer);
		numSpace = rockLen - IntToString(g_esData[tank].tankRock[client], str, sizeof str);
		AppendSpaceChar(buffer, sizeof buffer, numSpace);
		len = strlen(buffer);
		Format(buffer[len], sizeof buffer - len, "{olive}%s {default}Rock(s) ", str);
		AppendSpaceChar(buffer, sizeof buffer, numSpace);

		len = strlen(buffer);
		numSpace = hitLen - IntToString(g_esData[tank].tankHittable[client], str, sizeof str);
		AppendSpaceChar(buffer, sizeof buffer, numSpace);
		len = strlen(buffer);
		Format(buffer[len], sizeof buffer - len, "{olive}%s {default}Entities ", str);
		AppendSpaceChar(buffer, sizeof buffer, numSpace);

		len = strlen(buffer);
		Format(buffer[len], sizeof buffer - len, "{blue}%N", client);

		CPrintToChatAll("%s", buffer);
	}

	delete aClients;
}

void AppendSpaceChar(char[] buffer, int maxlength, int numSpace) {
	int len;
	for (int i; i < numSpace; i++) {
		len = strlen(buffer);
		strcopy(buffer[len], maxlength - len, " ");
	}
}

bool IsActive(int tank, int client) {
	return g_esData[tank].tankDmg[client] > 0 || g_esData[tank].tankClaw[client] > 0 || g_esData[tank].tankRock[client] > 0 || g_esData[tank].tankHittable[client] > 0;
}

void ClearTankData() {
	for (int i = 1; i <= MaxClients; i++)
		g_esData[i].CleanTank();
}
