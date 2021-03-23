#include <sourcemod>
#include <sdktools>
#define ZOMBIECLASS_SMOKER 1
#define ZOMBIECLASS_BOOMER 2
#define ZOMBIECLASS_HUNTER 3
#define ZOMBIECLASS_SPITTER 4
#define ZOMBIECLASS_JOCKEY 5
#define ZOMBIECLASS_CHARGER 6
#define ZOMBIECLASS_TANK 8
#define MaxHealth 100

public Plugin:myinfo = 
{
	name = "L4D2 回血",
	author = "fenghf &网通|冯华锋FHF",
	description = "L4D2 回血",
	version = "1.0.6",
	url = "http://bbs.3dmgame.com/l4d"
}

public OnPluginStart()   
{   
	decl String:game[12];
	GetGameFolderName(game, sizeof(game));
	if (StrContains(game, "left4dead") == -1) SetFailState("只能在 Left 4 Dead 1 or 2 运行!");
	RegAdminCmd("sm_hp", Command_GiveHp, ADMFLAG_KICK|ADMFLAG_VOTE|ADMFLAG_GENERIC|ADMFLAG_BAN|ADMFLAG_CHANGEMAP, "回血.");
	RegConsoleCmd("anyhp", AnyHp)
}

public Action:Command_GiveHp(client, args) 
{
	new Handle:menu = CreateMenu(GiveHp_Menu)
	new String:name[32];
	GetClientName(client, name, 32);
	SetMenuTitle(menu, "选择回血")
	AddMenuItem(menu, "option1", "自己回血");
	AddMenuItem(menu, "option2", "所有幸存者");
	AddMenuItem(menu, "option3", "玩家幸存者");
	AddMenuItem(menu, "option4", "电脑幸存者");
	AddMenuItem(menu, "option5", "所有特感");
	AddMenuItem(menu, "option6", "玩家特感");
	AddMenuItem(menu, "option7", "电脑特感");
	AddMenuItem(menu, "option8", "所有人");
	AddMenuItem(menu, "option9", "所有玩家");
	AddMenuItem(menu, "option10", "所有电脑");
	
	SetMenuExitButton(menu, true)
	DisplayMenu(menu, client, MENU_TIME_FOREVER)

	return Plugin_Handled
}
public GiveHp_Menu(Handle:menu, MenuAction:action, client, itemNum)
{
	if ( action == MenuAction_Select ) 
	{
		switch (itemNum)
		{
			case 0: 
			{
				new flags = GetCommandFlags("give");	
				SetCommandFlags("give", flags & ~FCVAR_CHEAT);
				if (IsClientInGame(client) && GetClientTeam(client) == 2  && IsPlayerAlive(client))
				{
					FakeClientCommand(client, "give health");
					//SetEntityHealth(client, MaxHealth);
					PrintToChatAll("\x03[自己回血]玩家 \x04%N \x03回血",client);
				}
				else
				if (IsClientInGame(client) && GetClientTeam(client) == 3 && IsPlayerAlive(client)) 
				{
					new class = GetEntProp(client, Prop_Send, "m_zombieClass");
					if (class == ZOMBIECLASS_SMOKER)
					{
						SetEntityHealth(client, 250);
						PrintToChatAll("\x03[自己回血]玩家 \x04%N \x03Smoker 回血",client);
					}
					else
					if (class == ZOMBIECLASS_BOOMER)
					{
						SetEntityHealth(client, 50);
						PrintToChatAll("\x03[自己回血]玩家 \x04%N \x03Boomer 回血",client);
					}
					else
					if (class == ZOMBIECLASS_HUNTER)
					{
						SetEntityHealth(client, 250);
						PrintToChatAll("\x03[自己回血]玩家 \x04%N \x03Hunter 回血",client);
					}
					else
					if (class == ZOMBIECLASS_SPITTER)
					{
						SetEntityHealth(client, 100);
						PrintToChatAll("\x03[自己回血]玩家 \x04%N \x03Spitter 回血",client);
					}
					else
					if (class == ZOMBIECLASS_JOCKEY)
					{
						decl String:game_name[64];
						GetGameFolderName(game_name, sizeof(game_name));
						if (!StrEqual(game_name, "left4dead2", false))
						{
							SetEntityHealth(client, 6000);
							PrintToChatAll("\x03[自己回血]玩家 \x04%N \x03Tank 回血",client);
						}
						else
						{
							SetEntityHealth(client, 325);
							PrintToChatAll("\x03[自己回血]玩家 \x04%N \x03Jockey 回血",client);
						}
					}
					else
					if (class == ZOMBIECLASS_CHARGER)
					{
						SetEntityHealth(client, 600);
						PrintToChatAll("\x03[自己回血]玩家 \x04%N \x03Charger 回血",client);
					}
					else
					if (class == ZOMBIECLASS_TANK)
					{
						SetEntityHealth(client, 6000);
						PrintToChatAll("\x03[自己回血]玩家 \x04%N \x03Tank 回血",client);
					}
				}
				SetCommandFlags("give", flags|FCVAR_CHEAT);
			}
			case 1: 
			{
				for (new i = 1; i <= MaxClients; i++)
				{
					new flags = GetCommandFlags("give");	
					SetCommandFlags("give", flags & ~FCVAR_CHEAT);
					if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
					{
						FakeClientCommand(i, "give health");
						//SetEntityHealth(i, MaxHealth);
						PrintToChatAll("\x03[所有幸存者]玩家 \x04%N \x03回血",i);
					}
					SetCommandFlags("give", flags|FCVAR_CHEAT);
				}
			}
			case 2: 
			{
				for (new i = 1; i <= MaxClients; i++)
				{
					new flags = GetCommandFlags("give");	
					SetCommandFlags("give", flags & ~FCVAR_CHEAT);
					if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && !IsFakeClient(i))
					{
						FakeClientCommand(i, "give health");
						SetEntityHealth(i, MaxHealth);
						PrintToChatAll("\x03[玩家幸存者]玩家 \x04%N \x03回血",i);
					}
					SetCommandFlags("give", flags|FCVAR_CHEAT);
				}
			}
			case 3:
			{
				for (new i = 1; i <= MaxClients; i++)
				{
					new flags = GetCommandFlags("give");	
					SetCommandFlags("give", flags & ~FCVAR_CHEAT);
					if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
					{
						FakeClientCommand(i, "give health");
						SetEntityHealth(i, MaxHealth);
						PrintToChatAll("\x03[电脑幸存者]玩家 \x04%N \x03回血",i);
					}
					SetCommandFlags("give", flags|FCVAR_CHEAT);
				}
			}
			case 4: 
			{
				for (new i = 1; i <= MaxClients; i++)
				{
					if (IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i)) 
					{
						new class = GetEntProp(i, Prop_Send, "m_zombieClass");
						if (class == ZOMBIECLASS_SMOKER)
						{
							SetEntityHealth(i, 250);
							PrintToChatAll("\x03[所有特感]玩家 \x04%N \x03Smoker 回血",i);
						}
						else
						if (class == ZOMBIECLASS_BOOMER)
						{
							SetEntityHealth(i, 50);
							PrintToChatAll("\x03[所有特感]玩家 \x04%N \x03Boomer 回血",i);
						}
						else
						if (class == ZOMBIECLASS_HUNTER)
						{
							SetEntityHealth(i, 250);
							PrintToChatAll("\x03[所有特感]玩家 \x04%N \x03Hunter 回血",i);
						}
						else
						if (class == ZOMBIECLASS_SPITTER)
						{
							SetEntityHealth(i, 100);
							PrintToChatAll("\x03[所有特感]玩家 \x04%N \x03Spitter 回血",i);
						}
						else
						if (class == ZOMBIECLASS_JOCKEY)
						{
							decl String:game_name[64];
							GetGameFolderName(game_name, sizeof(game_name));
							if (!StrEqual(game_name, "left4dead2", false))
							{
								SetEntityHealth(i, 6000);
								PrintToChatAll("\x03[所有特感]玩家 \x04%N \x03Tank 回血",i);
							}
							else
							{
								SetEntityHealth(i, 325);
								PrintToChatAll("\x03[所有特感]玩家 \x04%N \x03Jockey 回血",i);
							}
						}
						else
						if (class == ZOMBIECLASS_CHARGER)
						{
							SetEntityHealth(i, 600);
							PrintToChatAll("\x03[所有特感]玩家 \x04%N \x03Charger 回血",i);
						}
						else
						if (class == ZOMBIECLASS_TANK)
						{
							SetEntityHealth(i, 6000);
							PrintToChatAll("\x03[所有特感]玩家 \x04%N \x03Tank 回血",i);
						}
					}
				}
			}
			case 5:
			{
				for (new i = 1; i <= MaxClients; i++)
				{
					if (IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && !IsFakeClient(i)) 
					{
						new class = GetEntProp(i, Prop_Send, "m_zombieClass");
						if (class == ZOMBIECLASS_SMOKER)
						{
							SetEntityHealth(i, 250);
							PrintToChatAll("\x03[玩家特感]玩家 \x04%N \x03Smoker 回血",i);
						}
						else
						if (class == ZOMBIECLASS_BOOMER)
						{
							SetEntityHealth(i, 50);
							PrintToChatAll("\x03[玩家特感]玩家 \x04%N \x03Boomer 回血",i);
						}
						else
						if (class == ZOMBIECLASS_HUNTER)
						{
							SetEntityHealth(i, 250);
							PrintToChatAll("\x03[玩家特感]玩家 \x04%N \x03Hunter 回血",i);
						}
						else
						if (class == ZOMBIECLASS_SPITTER)
						{
							SetEntityHealth(i, 100);
							PrintToChatAll("\x03[玩家特感]玩家 \x04%N \x03Spitter 回血",i);
						}
						else
						if (class == ZOMBIECLASS_JOCKEY)
						{
							decl String:game_name[64];
							GetGameFolderName(game_name, sizeof(game_name));
							if (!StrEqual(game_name, "left4dead2", false))
							{
								SetEntityHealth(i, 6000);
								PrintToChatAll("\x03[玩家特感]玩家 \x04%N \x03Tank 回血",i);
							}
							else
							{
								SetEntityHealth(i, 325);
								PrintToChatAll("\x03[玩家特感]玩家 \x04%N \x03Jockey 回血",i);
							}
						}
						else
						if (class == ZOMBIECLASS_CHARGER)
						{
							SetEntityHealth(i, 600);
							PrintToChatAll("\x03[玩家特感]玩家 \x04%N \x03Charger 回血",i);
						}
						else
						if (class == ZOMBIECLASS_TANK)
						{
							SetEntityHealth(i, 6000);
							PrintToChatAll("\x03[玩家特感]玩家 \x04%N \x03Tank 回血",i);
						}
					}
				}
			}
			case 6:
			{
				for (new i = 1; i <= MaxClients; i++)
				{
					if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i)) 
					{
						new class = GetEntProp(i, Prop_Send, "m_zombieClass");
						if (class == ZOMBIECLASS_SMOKER)
						{
							SetEntityHealth(i, 250);
							PrintToChatAll("\x03[电脑特感]玩家 \x04%N \x03Smoker 回血",i);
						}
						else
						if (class == ZOMBIECLASS_BOOMER)
						{
							SetEntityHealth(i, 50);
							PrintToChatAll("\x03[电脑特感]玩家 \x04%N \x03Boomer 回血",i);
						}
						else
						if (class == ZOMBIECLASS_HUNTER)
						{
							SetEntityHealth(i, 250);
							PrintToChatAll("\x03[电脑特感]玩家 \x04%N \x03Hunter 回血",i);
						}
						else
						if (class == ZOMBIECLASS_SPITTER)
						{
							SetEntityHealth(i, 100);
							PrintToChatAll("\x03[电脑特感]玩家 \x04%N \x03Spitter 回血",i);
						}
						else
						if (class == ZOMBIECLASS_JOCKEY)
						{
							decl String:game_name[64];
							GetGameFolderName(game_name, sizeof(game_name));
							if (!StrEqual(game_name, "left4dead2", false))
							{
								SetEntityHealth(i, 6000);
								PrintToChatAll("\x03[电脑特感]玩家 \x04%N \x03Tank 回血",i);
							}
							else
							{
								SetEntityHealth(i, 325);
								PrintToChatAll("\x03[电脑特感]玩家 \x04%N \x03Jockey 回血",i);
							}
						}
						else
						if (class == ZOMBIECLASS_CHARGER)
						{
							SetEntityHealth(i, 600);
							PrintToChatAll("\x03[电脑特感]玩家 \x04%N \x03Charger 回血",i);
						}
						else
						if (class == ZOMBIECLASS_TANK)
						{
							SetEntityHealth(i, 6000);
							PrintToChatAll("\x03[电脑特感]玩家 \x04%N \x03Tank 回血",i);
						}
					}
				}
			}
			case 7:
			{
				FakeClientCommand(client,"anyhp");
			}
			case 8:
			{
				for (new i = 1; i <= MaxClients; i++)
				{
					new flags = GetCommandFlags("give");	
					SetCommandFlags("give", flags & ~FCVAR_CHEAT);
					if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && !IsFakeClient(i))
					{
						FakeClientCommand(i, "give health");
						SetEntityHealth(i, MaxHealth);
						PrintToChatAll("\x03[所有玩家]玩家 \x04%N \x03 回血",i);
					}
					else
					if (IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && !IsFakeClient(i)) 
					{
						new class = GetEntProp(i, Prop_Send, "m_zombieClass");
						if (class == ZOMBIECLASS_SMOKER)
						{
							SetEntityHealth(i, 250);
							PrintToChatAll("\x03[所有玩家]玩家 \x04%N \x03Smoker 回血",i);
						}
						else
						if (class == ZOMBIECLASS_BOOMER)
						{
							SetEntityHealth(i, 50);
							PrintToChatAll("\x03[所有玩家]玩家 \x04%N \x03Boomer 回血",i);
						}
						else
						if (class == ZOMBIECLASS_HUNTER)
						{
							SetEntityHealth(i, 250);
							PrintToChatAll("\x03[所有玩家]玩家 \x04%N \x03Hunter 回血",i);
						}
						if (class == ZOMBIECLASS_SPITTER)
						{
							SetEntityHealth(i, 100);
							PrintToChatAll("\x03[所有玩家]玩家 \x04%N \x03Spitter 回血",i);
						}
						else
						if (class == ZOMBIECLASS_JOCKEY)
						{
							decl String:game_name[64];
							GetGameFolderName(game_name, sizeof(game_name));
							if (!StrEqual(game_name, "left4dead2", false))
							{
								SetEntityHealth(i, 6000);
								PrintToChatAll("\x03[所有玩家]玩家 \x04%N \x03Tank 回血",i);
							}
							else
							{
								SetEntityHealth(i, 325);
								PrintToChatAll("\x03[所有玩家]玩家 \x04%N \x03Jockey 回血",i);
							}
						}
						else
						if (class == ZOMBIECLASS_CHARGER)
						{
							SetEntityHealth(i, 600);
							PrintToChatAll("\x03[所有玩家]玩家 \x04%N \x03Charger 回血",i);
						}
						else
						if (class == ZOMBIECLASS_TANK)
						{
							SetEntityHealth(i, 6000);
							PrintToChatAll("\x03[所有玩家]玩家 \x04%N \x03Tank 回血",i);
						}
					}
					SetCommandFlags("give", flags|FCVAR_CHEAT);
				}
			}
			case 9:
			{
				for (new i = 1; i <= MaxClients; i++)
				{
					new flags = GetCommandFlags("give");	
					SetCommandFlags("give", flags & ~FCVAR_CHEAT);
					if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
					{
						FakeClientCommand(i, "give health");
						SetEntityHealth(i, MaxHealth);
						PrintToChatAll("\x03[所有电脑]玩家 \x04%N \x03 回血",i);
					}
					else
					if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i)) 
					{
						new class = GetEntProp(i, Prop_Send, "m_zombieClass");
						if (class == ZOMBIECLASS_SMOKER)
						{
							SetEntityHealth(i, 250);
							PrintToChatAll("\x03[所有电脑]玩家 \x04%N \x03Smoker 回血",i);
						}
						else
						if (class == ZOMBIECLASS_BOOMER)
						{
							SetEntityHealth(i, 50);
							PrintToChatAll("\x03[所有电脑]玩家 \x04%N \x03Boomer 回血",i);
						}
						else
						if (class == ZOMBIECLASS_HUNTER)
						{
							SetEntityHealth(i, 250);
							PrintToChatAll("\x03[所有电脑]玩家 \x04%N \x03Hunter 回血",i);
						}
						if (class == ZOMBIECLASS_SPITTER)
						{
							SetEntityHealth(i, 100);
							PrintToChatAll("\x03[所有电脑]玩家 \x04%N \x03Spitter 回血",i);
						}
						else
						if (class == ZOMBIECLASS_JOCKEY)
						{
							decl String:game_name[64];
							GetGameFolderName(game_name, sizeof(game_name));
							if (!StrEqual(game_name, "left4dead2", false))
							{
								SetEntityHealth(i, 6000);
								PrintToChatAll("\x03[所有电脑]玩家 \x04%N \x03Tank 回血",i);
							}
							else
							{
								SetEntityHealth(i, 325);
								PrintToChatAll("\x03[所有电脑]玩家 \x04%N \x03Jockey 回血",i);
							}
						}
						else
						if (class == ZOMBIECLASS_CHARGER)
						{
							SetEntityHealth(i, 600);
							PrintToChatAll("\x03[所有电脑]玩家 \x04%N \x03Charger 回血",i);
						}
						else
						if (class == ZOMBIECLASS_TANK)
						{
							SetEntityHealth(i, 6000);
							PrintToChatAll("\x03[所有电脑]玩家 \x04%N \x03Tank 回血",i);
						}
					}
					SetCommandFlags("give", flags|FCVAR_CHEAT);
				}
			}
		}
	}
}
public Action:AnyHp(client, args)
{
	AnyHps()
}
public AnyHps()
{
	new flags = GetCommandFlags("give");	
	SetCommandFlags("give", flags & ~FCVAR_CHEAT);
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
		{
			FakeClientCommand(i, "give health");
			SetEntityHealth(i, MaxHealth);
			PrintToChatAll("\x03[所有人]玩家 \x04%N \x03回血",i);
		}
		else
		if (IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i)) 
		{
			new class = GetEntProp(i, Prop_Send, "m_zombieClass");
			if (class == ZOMBIECLASS_SMOKER)
			{
				SetEntityHealth(i, 250);
				PrintToChatAll("\x03[所有人]玩家 \x04%N \x03Smoker回血",i);
			}
			else
			if (class == ZOMBIECLASS_BOOMER)
			{
				SetEntityHealth(i, 50);
				PrintToChatAll("\x03[所有人]玩家 \x04%N \x03Boomer回血",i);
			}
			else
			if (class == ZOMBIECLASS_HUNTER)
			{
				SetEntityHealth(i, 250);
				PrintToChatAll("\x03[所有人]玩家 \x04%N \x03Hunter回血",i);
			}
			else
            if (class == ZOMBIECLASS_SPITTER)
			{
				SetEntityHealth(i, 100);
				PrintToChatAll("\x03[所有人]玩家 \x04%N \x03Spitter 回血",i);
			}
			else
			if (class == ZOMBIECLASS_JOCKEY)
			{
				decl String:game_name[64];
				GetGameFolderName(game_name, sizeof(game_name));
				if (!StrEqual(game_name, "left4dead2", false))
				{
					SetEntityHealth(i, 6000);
					PrintToChatAll("\x03[所有人]玩家 \x04%N \x03Tank 回血",i);
				}
				else
				{
					SetEntityHealth(i, 325);
					PrintToChatAll("\x03[所有人]玩家 \x04%N \x03Jockey回血",i);
				}
			}
			else
			if (class == ZOMBIECLASS_CHARGER)
			{
				SetEntityHealth(i, 600);
				PrintToChatAll("\x03[所有人]玩家 \x04%N \x03Charger回血",i);
			}
			else
			if (class == ZOMBIECLASS_TANK)
			{
				SetEntityHealth(i, 6000);
				PrintToChatAll("\x03[所有人]玩家 \x04%N \x03Tank回血",i);
			}
		}
	}
	SetCommandFlags("give", flags|FCVAR_CHEAT);
}