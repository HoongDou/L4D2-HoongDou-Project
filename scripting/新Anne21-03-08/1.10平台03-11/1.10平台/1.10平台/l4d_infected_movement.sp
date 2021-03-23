#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#define CVAR_FLAGS			FCVAR_NOTIFY
ConVar g_hSpeedTank, g_hSpeedTankDef;
float g_fSpeedTank, g_fSpeedTankDef;
float g_fTime[MAXPLAYERS+1];


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
	g_hSpeedTank =		CreateConVar(	"l4d_infected_movement_speed_tank",		"250",			"How fast can Tanks move while using their ability.", CVAR_FLAGS );
	g_hSpeedTank.AddChangeHook(ConVarChanged_Cvars);
	g_hSpeedTankDef = FindConVar("z_tank_speed");
	g_hSpeedTankDef.AddChangeHook(ConVarChanged_Cvars);
}



// ====================================================================================================
//					CVARS
// ====================================================================================================
public void OnConfigsExecuted()
{
	IsAllowed();
}
public void ConVarChanged_Cvars(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_fSpeedTank = g_hSpeedTank.FloatValue;
	g_fSpeedTankDef = g_hSpeedTankDef.FloatValue;
}

void IsAllowed()
{
	GetCvars();
	HookEvent("round_end",			Event_Reset);
	HookEvent("round_start",		Event_Reset);
	HookEvent("ability_use",		Event_Use);
	HookEvent("player_death",		Event_Death);
}

// ====================================================================================================
//					EVENTS
// ====================================================================================================
public void Event_Reset(Event event, const char[] name, bool dontBroadcast)
{
	ResetPlugin();
}

void ResetPlugin()
{
	for( int i = 0; i < sizeof(g_fTime); i++ )
	{
		g_fTime[i] = 0.0;
	}
}

public void Event_Death(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if( !client || !IsClientInGame(client) || GetClientTeam(client) != 3 ) return;

	int class = GetEntProp(client, Prop_Send, "m_zombieClass");
	if(class == 8 )
	{
		SDKUnhook(client, SDKHook_PostThinkPost, OnThinkFunk);
		SDKUnhook(client, SDKHook_PreThink, OnThinkFunk);
		SDKUnhook(client, SDKHook_PreThinkPost, OnThinkFunk);

		SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", g_fSpeedTankDef);
	}
}

public void Event_Use(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if( !client || !IsClientInGame(client) ) return;
	// Event check
	char sUse[16];
	event.GetString("ability", sUse, sizeof(sUse));
	if(strcmp(sUse, "ability_throw") == 0)
	{
		if( g_fTime[client] - GetGameTime() < 0.0 )
		{
			g_fTime[client] = GetGameTime() + 0.4;
			// Hooked 3 times, because each alone is not enough, this creates the smoothest play with minimal movement stutter
			SDKHook(client, SDKHook_PostThinkPost, OnThinkFunk);
			SDKHook(client, SDKHook_PreThink, OnThinkFunk);
			SDKHook(client, SDKHook_PreThinkPost, OnThinkFunk);
		}
	}
}
public void OnThinkFunk(int client)
{
	if(GetEntProp(client, Prop_Send, "m_zombieClass") != 8 || !IsPlayerAlive(client))
	return;
	if( g_fTime[client] - GetGameTime() > 0.0 )
	{
		SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", g_fSpeedTank);
		SetEntPropFloat(client, Prop_Send, "m_flStamina", 0.0);
	} 
	else 
	{
		g_fTime[client] = 0.0;
		SDKUnhook(client, SDKHook_PostThinkPost, OnThinkFunk);
		SDKUnhook(client, SDKHook_PreThink, OnThinkFunk);
		SDKUnhook(client, SDKHook_PreThinkPost, OnThinkFunk);
		SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", g_fSpeedTankDef);
	}
}