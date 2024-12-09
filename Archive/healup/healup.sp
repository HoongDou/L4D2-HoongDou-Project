#pragma semicolon 1
#include <left4dhooks>

public Plugin:myinfo =
{
	name = "healup",
	author = "HoongDou",
	description = "Restore health for each survivors when they left saferoom for first time",
	version = "1.0",
	url = ""
};

new bool:CheckHealthDone=false;

stock CheatCommand(Client, const String:command[], const String:arguments[])
{
	new admindata = GetUserFlagBits(Client);
	SetUserFlagBits(Client, ADMFLAG_ROOT);
	new flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(Client, "%s %s", command, arguments);
	SetCommandFlags(command, flags);
	SetUserFlagBits(Client, admindata);
}

public Action:L4D_OnFirstSurvivorLeftSafeArea(int client)
{
	for(new i = 1; i <= MaxClients; i++)
	{
		if(CheckHealthDone)==false
		{
			if(IsClientConnected(i) && IsClientInGame(i))
			{
				if(GetClientTeam(client) == 2)
				{
					if (IsPlayerAlive(client))
					{
						CheatCommand(i, "give", "health");
						CheckHealthDone=true;
						return Plugin_Stop;
					}
				}
			}
		}
		else
		return Plugin_Stop;
	}
	ReplyToCommand(client, "Restore Health Done");
}