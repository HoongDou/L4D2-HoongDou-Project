#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#define PLUGIN_VERSION "1.0" 


public Plugin:myinfo =
{
    name = "Tank try to punch rocks",
    author = "HoongDou",
    description = "Makes AI Tank doing a punch and rock attack simultaneously. ",
    version = PLUGIN_VERSION,
    url = "N/A"
}

int iPunchRocksFactor;
ConVar hPunchRocksFactor;

public OnPluginStart()
{
	CreateConVar("PunchRocks_Version", PLUGIN_VERSION, "Tank Punch Rocks Version", FCVAR_NOTIFY|FCVAR_REPLICATED|FCVAR_DONTRECORD);
	hPunchRocksFactor = CreateConVar("PunchRocksFactor", "2", "Factor the chance of tanks doing rock attack,1 means 1/1, 2 means 1/2 ,4 means 1/4,etc", FCVAR_NOTIFY|FCVAR_REPLICATED);
	AutoExecConfig(true, "l4d2_PunchRocks");
}

public Action:OnPlayerRunCmd(client, &buttons)
{
    if (IsClientInGame(client) && IsPlayerAlive(client) && (GetClientTeam(client) == 3) && IsFakeClient(client) && (GetEntProp(client, Prop_Send, "m_zombieClass") == 8))
    {
		if (buttons & IN_ATTACK)
        {
			iPunchRocksFactor = hPunchRocksFactor.IntValue;
			switch(GetRandomInt(1, iPunchRocksFactor))
			{		
				case 1:
				{
					buttons |= IN_ATTACK2;
				}
			}
		}
    }
    
    return Plugin_Continue;
}