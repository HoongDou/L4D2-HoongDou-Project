#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
ConVar g_hGameIdle;
ConVar g_hCvarChange;
ConVar g_hSMNotity;
ConVar g_hGameDisconnect;
ConVar g_hL4dToolz;
bool g_bGameIdle;
bool g_bCvarChange;
bool g_bSMNotity;
bool g_bGameDisconnect;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if(test != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	HookEvent("server_cvar", Event_ServerCvar, EventHookMode_Pre);
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
	HookUserMessage(GetUserMessageId("TextMsg"), TextMsg, true);
	g_hGameIdle = CreateConVar("sms_game_idle_notify_block", "1", "屏蔽游戏自带的玩家闲置提示.");
	g_hCvarChange = CreateConVar("sms_cvar_change_notify_block", "1", "屏蔽游戏自带的ConVar更改提示.");
	g_hSMNotity = CreateConVar("sms_sourcemod_sm_notify_admin", "0", "屏蔽sourcemod平台自带的SM提示？(1-只向管理员显示,0-对所有人屏蔽).");
	g_hGameDisconnect = CreateConVar("sms_game_disconnect_notify_block", "1", "屏蔽游戏自带的玩家离开提示.");

	//AutoExecConfig(true, "sms");

	g_hL4dToolz = FindConVar("sv_maxplayers");
	g_hL4dToolz.AddChangeHook(ConVarChanged);
	g_hGameIdle.AddChangeHook(ConVarChanged);
	g_hCvarChange.AddChangeHook(ConVarChanged);
	g_hSMNotity.AddChangeHook(ConVarChanged);
	g_hGameDisconnect.AddChangeHook(ConVarChanged);
}

public void OnConfigsExecuted()
{
	GetCvars();
}

public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_bGameIdle = g_hGameIdle.BoolValue;
	g_bCvarChange = g_hCvarChange.BoolValue;
	g_bSMNotity = g_hSMNotity.BoolValue;
	g_bGameDisconnect = g_hGameDisconnect.BoolValue;
}

// ------------------------------------------------------------------------
// 游戏自带的闲置提示和sourcemod平台自带的[SM]提示
// ------------------------------------------------------------------------
public Action TextMsg(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init)
{
	static char buffer[256];
	buffer[0] = 0;

	msg.ReadString(buffer, sizeof(buffer));
	if(g_bGameIdle && StrContains(buffer, "L4D_idle_spectator") != -1) //聊天栏提示：XXX 现已闲置。
		return Plugin_Handled;
	else if(StrContains(buffer, "\x03[SM]") == 0) //聊天栏以[SM]开头的消息。
	{
		if(g_bSMNotity)
		{
			DataPack datapack = new DataPack();
			datapack.WriteCell(playersNum);
			for(int i; i < playersNum; i++)
			{
				datapack.WriteCell(players[i]);
			}
			datapack.WriteString(buffer);
			RequestFrame(Delay_SM_Message, datapack);
		}

		return Plugin_Handled;
	}

	return Plugin_Continue;
}
public Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	if(g_bGameDisconnect)
		event.BroadcastDisabled = true;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client == 0 || IsFakeClient(client))
		return;
}
//https://forums.alliedmods.net/showthread.php?t=187570
public void Delay_SM_Message(DataPack datapack)
{
	datapack.Reset();
	int playersNum = datapack.ReadCell();
	int[] players = new int[playersNum];
	int client, count;
	for(int i; i < playersNum; i++)
	{
		client = datapack.ReadCell();
		if(IsClientInGame(client) && CheckCommandAccess(client, "", ADMFLAG_ROOT))
			players[count++] = client;
	}
	
	if(count == 0)
		return;
		
	playersNum = count;
	
	char buffer[256];
	datapack.ReadString(buffer, sizeof(buffer));
	delete datapack;
	ReplaceStringEx(buffer, sizeof(buffer), "[SM]", "\x04[SM]\x05");
	BfWrite bf = UserMessageToBfWrite(StartMessage("SayText2", players, playersNum, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS));
	bf.WriteByte(-1);
	bf.WriteByte(true);
	bf.WriteString(buffer);
	EndMessage();
}
// ------------------------------------------------------------------------
// ConVar更改提示
// ------------------------------------------------------------------------
public Action Event_ServerCvar(Event event, const char[] name, bool dontBroadcast)
{
    if(g_bCvarChange)
		return Plugin_Handled;

    return Plugin_Continue;
}