#pragma tabsize 0
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <l4d2util>

public OnRoundStart() 
{
	CreateTimer(1.0, RoundStartTimer);
}

public Action:RoundStartTimer(Handle:timer) 
{
	ReplaceMedikits();
}

public Action:ReplaceMedikits() 
{
	decl String:mapname[64];
    GetCurrentMap(mapname, sizeof(mapname));
    if( StrEqual(mapname, "c5m5_bridge") || StrEqual(mapname, "c13m4_cutthroatcreek"))
    {
       ServerCommand("sm_cvar z_common_limit 0");
    }
	for (new i = 1; i <= GetEntityCount(); i++) {
		if (IsValidEntity(i) && IsValidEdict(i)) {
			decl String:wpname[48];
			GetEdictClassname(i, wpname, sizeof(wpname));
			
			if (StrEqual(wpname, "weapon_spawn", false)) {
				if (GetEntProp(i, Prop_Send, "m_weaponID") == 12)
				{ReplaceSpawnPills(i);}
			}
			else if (StrEqual(wpname, "weapon_first_aid_kit_spawn", false))
			{ReplaceSpawnPills(i);}
		}
	}
}

ReplaceSpawnPills(entity) 
{
	RemoveEdict(entity);
}
