#pragma semicolon 1
#include <sourcemod>
#include <sdktools>

new iSurvivorIndex[NUM_OF_SURVIVORS] = 0;

SI_OnModuleStart()
{
	HookEvent("round_start"			, SI_BuildIndex_Event);
	HookEvent("round_end"			, SI_BuildIndex_Event);
	HookEvent("player_spawn"		, SI_BuildIndex_Event);
	HookEvent("player_disconnect"	, SI_BuildIndex_Event);
	HookEvent("player_death"		, SI_BuildIndex_Event);
	HookEvent("player_bot_replace"	, SI_BuildIndex_Event);
	HookEvent("bot_player_replace"	, SI_BuildIndex_Event);
	HookEvent("defibrillator_used"	, SI_BuildIndex_Event);
	HookEvent("player_team"			, SI_BuildIndexDelay_Event);
}

SI_BuildIndex()
{
	if (!IsServerProcessing() || !IsPluginEnabled()){return;}
	
	new ifoundsurvivors = 0;
	decl charr;
	
	// Make sure kicked survivors don't freak us out.
	for(new i = 0; i < NUM_OF_SURVIVORS;i++)
		iSurvivorIndex[i]=0;
	
	for (new client = 1; client <= MaxClients; client++)
	{
		if (ifoundsurvivors == NUM_OF_SURVIVORS)
		{
			break;
		}
		
		if (!IsClientInGame(client) || GetClientTeam(client) != 2)
		{
			continue;
		}
		
		charr = GetEntProp(client,Prop_Send,"m_survivorCharacter");
		ifoundsurvivors++;
		
		if (charr > 3 || charr < 0)
		{
			continue;
		}
		
		iSurvivorIndex[charr] = 0;
		
		if (!IsPlayerAlive(client))
		{
			continue;
		}
		
		iSurvivorIndex[charr] = client;
	}
}

public SI_BuildIndexDelay_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	CreateTimer(0.3, SI_BuildIndex_Timer);
}

public Action:SI_BuildIndex_Timer(Handle:timer)
{
	SI_BuildIndex();
}

public SI_BuildIndex_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	SI_BuildIndex();
}

GetSurvivorIndex(index)
{
	if (index < 0 || index > 3)
	{
		return 0;
	}
	
	return iSurvivorIndex[index];
}

bool:IsAnySurvivorsAlive()
{
	for(new index = 0;index < NUM_OF_SURVIVORS; index++)
	{
		if (iSurvivorIndex[index]) return true;
	}
	return false;
}