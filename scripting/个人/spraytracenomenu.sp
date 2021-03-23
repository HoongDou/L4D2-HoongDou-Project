#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#undef REQUIRE_PLUGIN

#define PLUGIN_VERSION "v5.8b"
#define MAXDIS 0
#define REFRESHRATE 1
#define FULLHUD 2
#define GLOBAL 3
#define NUMCVARS 4

//Nican: I am doing all this global for those "happy" people who spray something and quit the server
float g_arrSprayTrace[MAXPLAYERS + 1][3];
char g_arrSprayName[MAXPLAYERS + 1][128];
char g_arrSprayID[MAXPLAYERS + 1][32];
int g_arrSprayTime[MAXPLAYERS + 1];

// Misc. globals
ConVar g_arrCVars[NUMCVARS];
Handle g_hSprayTimer = null;


public Plugin myinfo = 
{
	name = "Spray Tracer No Menu",
	author = "Nican132, CptMoore, Lebson506th",
	description = "Traces sprays on the wall",
	version = PLUGIN_VERSION,
	url = "http://www.sourcemod.net/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart() 
{
	LoadTranslations("spraytracenomenu.phrases");
	LoadTranslations("common.phrases");

	CreateConVar("sm_spraynomenu_version", PLUGIN_VERSION, "Spray tracer plugin version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);

	g_arrCVars[MAXDIS] = CreateConVar("sm_spraynomenu_dista","50.0","How far away the spray will be traced to.");
	g_arrCVars[REFRESHRATE] = CreateConVar("sm_spraynomenu_refresh","1.0","How often the program will trace to see player's spray to the HUD. 0 to disable.");
	g_arrCVars[FULLHUD] = CreateConVar("sm_spray_fullhud","0","Toggles showing sprayer's name and Steam ID(1) or just sprayer's name(0) on the HUD");
	g_arrCVars[GLOBAL] = CreateConVar("sm_spraynomenu_global","1","Enables or disables global spray tracking. If this is on, sprays can still be tracked when a player leaves the server.");

	g_arrCVars[REFRESHRATE].AddChangeHook(TimerChanged);

	AddTempEntHook("Player Decal",PlayerSpray);

	CreateTimers();

	//AutoExecConfig(true, "plugin.spraytracenomenu");
}

/*
	Clears all stored sprays when the map changes.
	Also prechaches the model.
*/

public void OnMapStart() 
{
	for(int i = 1; i <= MaxClients; i++)
	{
		ClearVariables(i);
	}
}

/*
	Clears all stored sprays for a disconnecting
	client if global spray tracing is disabled.
*/

public void OnClientDisconnect(int client) 
{
	if(!g_arrCVars[GLOBAL].BoolValue)
		ClearVariables(client);
}

/*
	Clears the stored sprays for the given client.
*/

stock void ClearVariables(int client) 
{
	g_arrSprayTrace[client][0] = 0.0;
	g_arrSprayTrace[client][1] = 0.0;
	g_arrSprayTrace[client][2] = 0.0;
	g_arrSprayName[client][0] = '\0';
	g_arrSprayID[client][0] = '\0';
	g_arrSprayTime[client] = 0;
}

/*
Records the location, name, ID, and time of all sprays
*/

public Action PlayerSpray(const char[] szTempEntName, const int[] arrClients, int iClientCount, float flDelay) 
{
	int client = TE_ReadNum("m_nPlayer");

	if(IsValidClient(client)) 
	{
		TE_ReadVector("m_vecOrigin", g_arrSprayTrace[client]);

		g_arrSprayTime[client] = RoundFloat(GetGameTime());
		FormatEx(g_arrSprayName[client], sizeof(g_arrSprayName[]), "%N", client);
		GetClientAuthId(client, AuthId_Steam2, g_arrSprayID[client], sizeof(g_arrSprayID[]));
	}
}

/*
Refresh handlers for tracing to HUD or hint message
*/

public void TimerChanged(Handle convar, const char[] oldValue, const char[] newValue) 
{
	CreateTimers();
}

stock void CreateTimers() 
{
	delete g_hSprayTimer;

	float timer = g_arrCVars[REFRESHRATE].FloatValue;

	if(timer > 0.0)
		g_hSprayTimer = CreateTimer(timer, CheckAllTraces, _, TIMER_REPEAT);
}

/*
Handle tracing sprays to the HUD or hint message
*/

public Action CheckAllTraces(Handle timer)
{
	static float vecPos[3];

	//God pray for the processor
	for(int i = 1; i <= MaxClients; i++) 
	{
		if(!IsClientInGame(i) || IsFakeClient(i))
			continue;

		if(GetPlayerEye(i, vecPos)) 
		{
			for(int a = 1; a <= MaxClients; a++) 
			{
				if((g_arrSprayName[a][0]  == '\0') || (g_arrSprayID[a][0] == '\0'))
					continue;

				if(GetVectorDistance(vecPos, g_arrSprayTrace[a]) <= g_arrCVars[MAXDIS].FloatValue) 
				{
					if(g_arrCVars[FULLHUD].BoolValue)
						PrintHintText(i, "%T", "Sprayed", i, g_arrSprayName[a], g_arrSprayID[a]);
					else
						PrintHintText(i, "%T", "Sprayed Name", i, g_arrSprayName[a]);

					break;
				}
			}
		}
	}
}

/*
Helper Methods
*/

stock bool GetPlayerEye(int client, float vecPos[3]) 
{
	static float vecAngles[3], vecOrigin[3];

	GetClientEyePosition(client, vecOrigin);
	GetClientEyeAngles(client, vecAngles);

	static Handle hTrace;
	hTrace = TR_TraceRayFilterEx(vecOrigin, vecAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);

	static bool isVisible;
	isVisible = false;
	if(TR_DidHit(hTrace)) 
	{
	 	//This is the first function i ever saw that anything comes before the handle
		TR_GetEndPosition(vecPos, hTrace);
		isVisible = true;
	}

	delete hTrace;
	return isVisible;
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask)
{
 	if(entity <= MaxClients || !IsValidEntity(entity))
		return false;

	return true;
}

stock bool IsValidClient(int client) 
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}