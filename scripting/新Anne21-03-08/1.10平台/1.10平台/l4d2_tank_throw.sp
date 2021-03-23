//TANK转弯石头
//TANK丢石头姿势
//TANK拳头和石头力度控制
//特感加强插件
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#pragma tabsize 0
#define CMD_ATTACK 0
#include "includes/hardcoop_util.sp"
public Plugin:myinfo =
{
        name = "L4D2 Advanced Special Infected AI",
        author = "def075",
        description = "Advanced Special Infected AI",
        version = "0.4",
        url = ""
}

#define DEBUG_SPEED 0
#define DEBUG_EYE   0
#define DEBUG_KEY   0
#define DEBUG_ANGLE 0
#define DEBUG_VEL   0
#define DEBUG_AIM       0
#define DEBUG_POS       0

#define ZC_SMOKER       1
#define ZC_BOOMER       2
#define ZC_HUNTER       3
#define ZC_SPITTER      4
#define ZC_JOCKEY       5
#define ZC_CHARGER      6
#define ZC_WITCH        7
#define ZC_TANK         8

#define MAXPLAYERS1     (MAXPLAYERS+1)

#define VEL_MAX          450.0
#define MOVESPEED_TICK     1.0
#define EYEANGLE_TICK      0.2
#define TEST_TICK          2.0
#define MOVESPEED_MAX     1000
enum AimTarget
{
        AimTarget_Eye,
        AimTarget_Body,
        AimTarget_Chest
};

public OnPluginStart()
{
        HookEvent("round_start", onRoundStart);
        HookEvent("player_spawn", onPlayerSpawn);
}
public OnMapStart()
{
        CreateTimer(MOVESPEED_TICK, timerMoveSpeed, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

new bool:g_ai_enable[MAXPLAYERS1];
public Action:onRoundStart(Handle:event, String:event_name[], bool:dontBroadcast)
{
        for (new i = 0; i < MAXPLAYERS1; ++i) {
                g_ai_enable[i] = false;
        }
        initStatus();
}

public Action:onPlayerSpawn(Handle:event, String:event_name[], bool:dontBroadcast)
{
        new client = GetClientOfUserId(GetEventInt(event, "userid"));
        if (isSpecialInfectedBot(client))
		{
                // AI適用の有効無効を切り替える（タンクはこのフラグを無視する）
				g_ai_enable[client] = true;
        }
}

/* クライアントのキー入力処理
 *
 * ここでbotのキー入力を監視して書き換えることでbotをコントロールする
 *
 * buttons: 入力されたキー (enumはinclude/entity_prop_stock.inc参照)
 * vel: プレーヤーの速度？
 *      実プレーヤーだと
 *      [0]が↑↓入力で-450～+450.
 *      [1]が←→入力で-450～+450.
 *      botだと230
 *
 * angles: 視線の方向(マウスカーソルを向けている方向)？
 *      [0]がpitch(上下) -89～+89
 *      [1]がyaw(自分を中心に360度回転) -180～+180
 *
 *      これを変更しても視線は変わらないがIN_FORWARDに対する移動方向が変わる
 *
 * impulse: impules command なぞ
 *
 * buttons, vel, anglesは書き換えてPlugin_Changedを返せば操作に反映される.
 * ただ処理順の問題があってたとえばIN_USEのビットを落としてUSE Keyが使えないようにすると
 * 武器は取れないけどドアは開くみたいな事が起こりえる.
 *
 * ゲームフレームから呼ばれるようなのでできるだけ軽い処理にする.
 */
public Action:OnPlayerRunCmd(client, &buttons, &impulse,
                                                         Float:vel[3], Float:angles[3], &weapon)
{
        // 確認用...
#if (DEBUG_SPEED || DEBUG_KEY || DEBUG_EYE || DEBUG_ANGLE || DEBUG_VEL || DEBUG_AIM || DEBUG_POS)
        debugPrint(client, buttons, vel, angles);
#endif
        // 特殊のBOTのみ処理
        if (isSpecialInfectedBot(client)) {
                // versusだとゴースト状態のBotがいるけど
                // Coopだとゴーストなしでいきなり沸いてる?
                // 今回ゴーストは考慮しない
                if (!isGhost(client)) {
                        // 種類ごとの処理
                        new zombie_class = getZombieClass(client);
                        new Action:ret = Plugin_Continue;

                        if (zombie_class == ZC_TANK) {
                                ret = onTankRunCmd(client,  buttons, vel, angles);
                        } else if (g_ai_enable[client]) {
                                switch (zombie_class) {
                                case ZC_SMOKER: { ret = onSmokerRunCmd(client, buttons, vel, angles); }
								case ZC_JOCKEY: { ret = onJockeyRunCmd(client, buttons, vel, angles); }
								case ZC_BOOMER: { ret = onBoomerRunCmd(client, buttons, vel, angles); }
                                case ZC_HUNTER: { ret = onHunterRunCmd(client, buttons, vel, angles); }
								case ZC_CHARGER: { ret = onChargerRunCmd(client, buttons, vel, angles); }
                                case ZC_SPITTER: { ret = onSpitterRunCmd(client, buttons, vel, angles); }
                                }
                        }
                        // 最近のメイン攻撃時間を保存
                        if (buttons & IN_ATTACK) {
                                updateSIAttackTime();
                        }
                        return ret;
                }
        }
        return Plugin_Continue;
}

/**
 * スモーカーの処理
 *
 * チャンスがあれば舌を飛ばす
 */
stock Action:onSmokerRunCmd(client, &buttons, Float:vel[3], Float:angles[3])
{
	
	if (GetEntityMoveType(client) != MOVETYPE_LADDER) 
	{
	new target = GetClientAimTarget(client, true);
		if (target > 0 && isVisibleTo(client,target) && !IsPinned(target) && !isIncapacitated(target)) 
		{
		} 
		else
		{
			new new_target = -1;
			new Float:min_dist = 100000.0;
			new Float:self_pos[3], Float:target_pos[3];
			GetClientAbsOrigin(client, self_pos);
			for (new i = 1; i <= MaxClients; ++i) 
			{
				if (isSurvivor(i)&& IsPlayerAlive(i) && !isIncapacitated(i) && isVisibleTo(client,i) && !IsPinned(i))
				{
					new Float:dist;
					GetClientAbsOrigin(i, target_pos);
					dist = GetVectorDistance(self_pos, target_pos);
					if (dist < min_dist) 
					{
						min_dist = dist;
						new_target = i;
					}
				}
			}
			if (new_target > 0) 
			{
				if (angles[2] == 0.0) 
				{
					new Float:aim_angles[3];
					computeAimAngles(client, new_target, aim_angles, AimTarget_Chest);
					aim_angles[2] = 0.0;
					TeleportEntity(client, NULL_VECTOR, aim_angles, NULL_VECTOR);
					return Plugin_Changed;
				}
			}
		}
	}
	return Plugin_Continue;
}
stock Action:onBoomerRunCmd(client, &buttons, Float:vel[3], Float:angles[3])
{
	
	if (GetEntityMoveType(client) != MOVETYPE_LADDER) 
	{
	new target = GetClientAimTarget(client, true);
		if (target > 0 && isVisibleTo(client,target)) 
		{
		} 
		else
		{
			new new_target = -1;
			new Float:min_dist = 100000.0;
			new Float:self_pos[3], Float:target_pos[3];
			GetClientAbsOrigin(client, self_pos);
			for (new i = 1; i <= MaxClients; ++i) 
			{
				if (isSurvivor(i)&& IsPlayerAlive(i)&& !isIncapacitated(i)&& isVisibleTo(client,i) && !IsPinned(i))
				{
					new Float:dist;
					GetClientAbsOrigin(i, target_pos);
					dist = GetVectorDistance(self_pos, target_pos);
					if (dist < min_dist) 
					{
						min_dist = dist;
						new_target = i;
					}
				}
			}
			if (new_target > 0) 
			{
				if (angles[2] == 0.0) 
				{
					new Float:aim_angles[3];
					computeAimAngles(client, new_target, aim_angles, AimTarget_Chest);
					aim_angles[2] = 0.0;
					TeleportEntity(client, NULL_VECTOR, aim_angles, NULL_VECTOR);
					return Plugin_Changed;
				}
			}
		}
	}
	return Plugin_Continue;
}
/**
 * ハンターの処理
 *
 * 次のようにする
 * - 最初の飛び掛りのトリガーはBOTが自発的に行う
 * - BOTが飛び掛ったら一定の間攻撃モードをONにする
 * - 攻撃モードがONの場合さまざまな角度で連続的に飛びまくる動きと
 *   ターゲットを狙った飛びかかり（デフォルトの動き）を混ぜて飛び回る
 *
 * あと hunter_pounce_ready_range というCVARをを2000くらいに変更すると
 * 遠くにいるときでもしゃがむようになるの変更するとよい
 *
 * あと撃たれたときに後ろに飛んで逃げるっぽい動きに移行するのをやめさせたい
 */
#define HUNTER_FLY_DELAY             0.2
#define HUNTER_ATTACK_TIME           4.0
#define HUNTER_COOLDOWN_DELAY        2.0
#define HUNTER_FALL_DELAY            0.2
#define HUNTER_STATE_FLY_TYPE        0
#define HUNTER_STATE_FALL_FLAG       1
#define HUNTER_STATE_FLY_FLAG        2
#define HUNTER_REPEAT_SPEED          4
#define HUNTER_NEAR_RANGE          1000

stock Action:onHunterRunCmd(client, &buttons, Float:vel[3], Float:angles[3])
{
	
	if (GetEntityMoveType(client) != MOVETYPE_LADDER) 
	{
	new target = GetClientAimTarget(client, true);
    if (target > 0 && isVisibleTo(client,target) && !IsPinned(target) && !isIncapacitated(target)) 
	{

	} 
	else 
	{
        new new_target = -1;
        new Float:min_dist = 100000.0;
        new Float:self_pos[3], Float:target_pos[3];
		GetClientAbsOrigin(client, self_pos);
		for (new i = 1; i <= MaxClients; ++i) 
		{
			if (isSurvivor(i)&& IsPlayerAlive(i)&& !isIncapacitated(i)&& isVisibleTo(client,i)&& !IsPinned(i))
			{
				new Float:dist;
				GetClientAbsOrigin(i, target_pos);
				dist = GetVectorDistance(self_pos, target_pos);
				if (dist < min_dist) 
				{
					min_dist = dist;
					new_target = i;
				}
			}
		}
		if (new_target > 0) 
		{
			if (angles[2] == 0.0) 
			{
				new Float:aim_angles[3];
				computeAimAngles(client, new_target, aim_angles, AimTarget_Chest);
				aim_angles[2] = 0.0;
				TeleportEntity(client, NULL_VECTOR, aim_angles, NULL_VECTOR);
				return Plugin_Changed;
            }
        }
    }
	}
	
        new Action:ret = Plugin_Continue;
        new bool:internal_trigger = false;

        if (!delayExpired(client, 1, HUNTER_ATTACK_TIME)
                && GetEntityMoveType(client) != MOVETYPE_LADDER)
        {
                // 攻撃モード中はDUCK押しっぱなしかつATTACK連打する
                buttons |= IN_DUCK;
                if (GetRandomInt(0, HUNTER_REPEAT_SPEED) == 0) {
                        // ATTACKは離さないと効果がないので
                        // ランダムな間隔で押した状態を作る
                        buttons |= IN_ATTACK;
                        internal_trigger = true;
                }
                ret = Plugin_Changed;
        }
        if (!(GetEntityFlags(client) & FL_ONGROUND)
                && getState(client, HUNTER_STATE_FLY_FLAG) == 0)
        {
                // ジャンプ開始
                delayStart(client, 2);
                setState(client, HUNTER_STATE_FALL_FLAG, 0);
                setState(client, HUNTER_STATE_FLY_FLAG, 1);
        } else if (!(GetEntityFlags(client) & FL_ONGROUND)) {
                // 空中にいる場合
                if (getState(client, HUNTER_STATE_FLY_TYPE) == IN_FORWARD) {
                        // 角度を変えて飛ぶときは空中で↑入力を入れる
                        buttons |= IN_FORWARD;
                        vel[0] = VEL_MAX;
                        if (getState(client, HUNTER_STATE_FALL_FLAG) == 0
                                && delayExpired(client, 2, HUNTER_FALL_DELAY))
                        {
                                // 飛び始めてから少しして視線を変える
                                if (angles[2] == 0.0) 
								{
                                        angles[0] = GetRandomFloat(-30.0, 30.0);
                                        TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
                                }
                                setState(client, HUNTER_STATE_FALL_FLAG, 1);
                        }
                        ret = Plugin_Changed;
                }
        } else if (getState(client, 2) == 1) {
                // 着地
        } else {
                setState(client, HUNTER_STATE_FLY_FLAG, 0);
        }
        if (delayExpired(client, 0, HUNTER_FLY_DELAY)
                && (buttons & IN_ATTACK)
                && (GetEntityFlags(client) & FL_ONGROUND))
        {
                // 飛びかかり開始
                new Float:dist = nearestSurvivorDistance(client);

                delayStart(client, 0);
                if (!internal_trigger
                        && !(buttons & IN_BACK)
                        && dist < HUNTER_NEAR_RANGE
                        && delayExpired(client, 1, HUNTER_ATTACK_TIME + HUNTER_COOLDOWN_DELAY))
                {
                        // BOTがトリガーを入れて生存者に近い場合は攻撃モードに移行する
                        delayStart(client, 1); // このdelayが切れるまで攻撃モード
                }
                // ランダムな飛び方と
                // ターゲットを狙ったデフォルトの飛び方をランダムに繰り返す.
                if (GetRandomInt(0, 1) == 0) {
                        // ランダムで飛ぶ
                        if (dist < HUNTER_NEAR_RANGE) {
                                if (angles[2] == 0.0) 
								{
                                        if (GetRandomInt(0, 4) == 0) {
                                                // 高めに飛ぶ 1/5
                                                angles[0] = GetRandomFloat(-20.0, -30.0);
                                        } 
										else 
										{
                                                // 低めに飛ぶ
                                                angles[0] = GetRandomFloat(-10.0, 20.0);
                                        }
                                        // 視線を変更
                                        TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
                                }
                                // 空中で前入力を入れるフラグをセット
                                setState(client, HUNTER_STATE_FLY_TYPE, IN_FORWARD);
                        } else {
                                // デフォルトの飛び掛り
                                setState(client, HUNTER_STATE_FLY_TYPE, 0);
                        }
                } else {
                        // デフォルトの飛び掛り
                        setState(client, HUNTER_STATE_FLY_TYPE, 0);
                }
                ret = Plugin_Changed;
        }
        return ret;
}
stock Action:onJockeyRunCmd(client, &buttons, Float:vel[3], Float:angles[3])
{
	
	if (GetEntityMoveType(client) != MOVETYPE_LADDER) 
	{
	new target = GetClientAimTarget(client, true);
    if (target > 0 && isVisibleTo(client,target) && !IsPinned(target) && !isIncapacitated(target)) 
	{

	}  
	else
	{
		new new_target = -1;
        new Float:min_dist = 100000.0;
        new Float:self_pos[3], Float:target_pos[3];
		GetClientAbsOrigin(client, self_pos);
		for (new i = 1; i <= MaxClients; ++i) 
		{
			if (isSurvivor(i)&& IsPlayerAlive(i) && !isIncapacitated(i) && isVisibleTo(client,i)&& !IsPinned(i))
			{
				new Float:dist;
				GetClientAbsOrigin(i, target_pos);
				dist = GetVectorDistance(self_pos, target_pos);
				if (dist < min_dist) 
				{
					min_dist = dist;
					new_target = i;
				}
			}
		}
		if (new_target > 0) 
		{
			if (angles[2] == 0.0) 
			{
				new Float:aim_angles[3];
				computeAimAngles(client, new_target, aim_angles, AimTarget_Chest);
				aim_angles[2] = 0.0;
				TeleportEntity(client, NULL_VECTOR, aim_angles, NULL_VECTOR);
				return Plugin_Changed;
            }
        }
	}
	}
	return Plugin_Continue;
}
#define SPITTER_SPIT_DELAY 2.0
stock Action:onSpitterRunCmd(client, &buttons, Float:vel[3], Float:angles[3])
{
	
	
	
	if (GetEntityMoveType(client) != MOVETYPE_LADDER) 
	{
	new target = GetClientAimTarget(client, true);
    if (target > 0 && isVisibleTo(client,target) && hasPinned(target)) 
	{
	} 
	else
	{
    new new_target = -1;
    new Float:min_dist = 100000.0;
    new Float:self_pos[3], Float:target_pos[3];
	GetClientAbsOrigin(client, self_pos);
	for (new i = 1; i <= MaxClients; ++i) 
	{
		if (isSurvivor(i)&& IsPlayerAlive(i) && isVisibleTo(client,i) && hasPinned(i))
		{
			new Float:dist;
			GetClientAbsOrigin(i, target_pos);
			dist = GetVectorDistance(self_pos, target_pos);
			if (dist < min_dist) 
			{
				min_dist = dist;
				new_target = i;
			}
		}
	}
	if (new_target > 0) 
	{
		if (angles[2] == 0.0) 
		{
			new Float:aim_angles[3];
			computeAimAngles(client, new_target, aim_angles, AimTarget_Chest);
			aim_angles[2] = 0.0;
			TeleportEntity(client, NULL_VECTOR, aim_angles, NULL_VECTOR);
			return Plugin_Changed;
        }
		
    }
	}
	}
	if (buttons & IN_ATTACK) 
	{
        if (delayExpired(client, 1, SPITTER_SPIT_DELAY)) 
		{
            delayStart(client, 1);
            buttons |= IN_JUMP;
        }
	}
	return Plugin_Continue;
}
stock Action:onChargerRunCmd(client, &buttons, Float:vel[3], Float:angles[3])
{
	
	new abilityEnt = 0;
	if (GetEntityMoveType(client) != MOVETYPE_LADDER) 
	{
	new target = GetClientAimTarget(client, true);
    if (target > 0 && isVisibleTo(client,target) && !IsPinned(target) && !isIncapacitated(target)) 
	{
	} 
	else
	{
    new new_target = -1;
    new Float:min_dist = 100000.0;
    new Float:self_pos[3], Float:target_pos[3];
	GetClientAbsOrigin(client, self_pos);
	for (new i = 1; i <= MaxClients; ++i) 
	{
		if (isSurvivor(i)&& IsPlayerAlive(i) && isVisibleTo(client,i) && !isIncapacitated(i) && !IsPinned(i))
		{
			new Float:dist;
			GetClientAbsOrigin(i, target_pos);
			dist = GetVectorDistance(self_pos, target_pos);
			if (dist < min_dist) 
			{
				min_dist = dist;
				new_target = i;
			}
		}
	}
	if (new_target > 0) 
	{
		if(angles[2] == 0.0)
		{
			abilityEnt = GetEntPropEnt(client, Prop_Send, "m_customAbility");
                new bool:isCharging = false;
                if (abilityEnt > 0) 
				{
                    isCharging = (GetEntProp(abilityEnt, Prop_Send, "m_isCharging") > 0) ? true : false;
                }
                if (!isCharging && GetEntPropEnt(client, Prop_Send, "m_carryAttacker") == 0)
                {
                    new Float:aim_angles[3];
					computeAimAngles(client, new_target, aim_angles, AimTarget_Chest);
					aim_angles[2] = 0.0;
					TeleportEntity(client, NULL_VECTOR, aim_angles, NULL_VECTOR);
					return Plugin_Changed;
                }
		}
		
	}
				
	}
	}
	return Plugin_Continue;
}
public Action:L4D2_OnSelectTankAttack(client, &sequence) 
{
	if (IsFakeClient(client) && sequence == 50) {
		sequence = GetRandomInt(0, 1) ? 49 : 51;
		return Plugin_Handled;
	}
	return Plugin_Changed;
}

/**
 * タンクの処理
 *
 * - 近くに生存者がいればとにかく殴る
 * - 走っているときに直線的なジャンプで加速する
 * - 岩投げ中にターゲットしている人が見えなくなったらターゲットを変更する
 *   （投げる瞬間にターゲットが変わるとモーションと違う軌道に投げる）
 */
stock Action:onTankRunCmd(client, &buttons, Float:vel[3], Float:angles[3])
{
	if (buttons != IN_ATTACK && GetEntityMoveType(client) != MOVETYPE_LADDER) 
	{
		new target = GetClientAimTarget(client, true);
		if (target > 0 && isVisibleTo(client,target) && !hasPinned(target) && !isIncapacitated(target)) 
		{/*
			if (IsValidClient(target) && IsSurvivor(target)) 
			{
				new botID = GetClientUserId(client);
				new targetID = GetClientUserId(target);		
				L4D2_RunScript("CommandABot({cmd=%i,bot=GetPlayerFromUserID(%i),target=GetPlayerFromUserID(%i)})", CMD_ATTACK, botID, targetID); // attack			
			}
			*/
		} 
		else
		{
			new new_target = -1;
			new Float:min_dist = 100000.0;
			new Float:self_pos[3], Float:target_pos[3];
			GetClientAbsOrigin(client, self_pos);
			for (new i = 1; i <= MaxClients; ++i) 
			{
				if (isSurvivor(i)&& IsPlayerAlive(i) && !isIncapacitated(i) && isVisibleTo(client,i)&& !hasPinned(i))
				{
					new Float:dist;
					GetClientAbsOrigin(i, target_pos);
					dist = GetVectorDistance(self_pos, target_pos);
					if (dist < min_dist) 
					{
						min_dist = dist;
						new_target = i;
					}
				}
			}
			if (new_target > 0) 
			{
				if (angles[2] == 0.0) 
				{
					new Float:aim_angles[3];
					computeAimAngles(client, new_target, aim_angles, AimTarget_Chest);
					aim_angles[2] = 0.0;
					TeleportEntity(client, NULL_VECTOR, aim_angles, NULL_VECTOR);
					return Plugin_Changed;
				}
			}
		}			
	}
     return Plugin_Continue;
}
// clientの一番近くにいる生存者の距離を取得
//
// 今はトレースしていないので1階と2階とか隣の部屋とか
// 遮るものがあっても近くになってしまう
stock any:nearestSurvivorDistance(client)
{
        new Float:self[3];
        new Float:min_dist = 100000.0;

        GetClientAbsOrigin(client, self);
        for (new i = 1; i <= MaxClients; ++i) {
                if (IsClientInGame(i) && isSurvivor(i) && IsPlayerAlive(i) && !isIncapacitated(i) && !hasPinned(i)) {
                        new Float:target[3];
                        GetClientAbsOrigin(i, target);
                        new Float:dist = GetVectorDistance(self, target);
                        if (dist < min_dist) {
                                min_dist = dist;
                        }
                }
        }
        return min_dist;
}
stock any:nearestActiveSurvivorDistance(client)
{
        new Float:self[3];
        new Float:min_dist = 100000.0;

        GetClientAbsOrigin(client, self);
        for (new i = 1; i <= MaxClients; ++i) {
                if (IsClientInGame(i)
                        && isSurvivor(i)
                        && IsPlayerAlive(i)
                        && !isIncapacitated(i)
						&& !IsPinned(i))
                {
                        new Float:target[3];
                        GetClientAbsOrigin(i, target);
                        new Float:dist = GetVectorDistance(self, target);
                        if (dist < min_dist) {
                                min_dist = dist;
                        }
                }
        }
        return min_dist;
}

// clientから見える範囲で一番近い生存者を取得
stock any:nearestVisibleSurvivor(client)
{
        new Float:self[3];
        new Float:min_dist = 100000.0;
        new min_i = -1;
        GetClientAbsOrigin(client, self);
        for (new i = 1; i <= MaxClients; ++i) {
                if (IsClientInGame(i)
                        && isSurvivor(i)
                        && IsPlayerAlive(i)
                        && isVisibleTo(i)
						&& !isIncapacitated(i)
						&& !IsPinned(i))
                {
                        new Float:target[3];
                        GetClientAbsOrigin(i, target);
                        new Float:dist = GetVectorDistance(self, target);
                        if (dist < min_dist) 
						{
                                min_dist = dist;
                                min_i = i;
                        }
                }
        }
    return min_i;
}

// 感染者か
stock bool:isInfected(i)
{
    return GetClientTeam(i) == 3;
}
// ゴーストか
stock bool:isGhost(i)
{
    return isInfected(i) && GetEntProp(i, Prop_Send, "m_isGhost");
}
// 特殊感染者ボットか
stock bool:isSpecialInfectedBot(i)
{
    return i > 0 && i <= MaxClients && IsClientInGame(i) && IsFakeClient(i) && isInfected(i);
}
// 生存者か
// 死んでるとかダウンしてるとか拘束されてるとかも見たほうがいいでしょう..
stock bool:isSurvivor(i)
{
    return i > 0 && i <= MaxClients && IsClientInGame(i) && GetClientTeam(i) == 2;
}
// 感染者の種類を取得
stock any:getZombieClass(client)
{
    return GetEntProp(client, Prop_Send, "m_zombieClass");
}

/**
 * キー入力処理内でビジーループと状態維持に使っている変数
 *
 * 死んだときにクリアしないと前の情報が残ってるけど
 * あまり気にならないような作りにしてる
 */
// 1 client 8delayを持っとく
new Float:g_delay[MAXPLAYERS1][8];
stock delayStart(client, no)
{
    g_delay[client][no] = GetGameTime();
}
stock bool:delayExpired(client, no, Float:delay)
{
    return GetGameTime() - g_delay[client][no] > delay;
}
// 1 player 8state を持っとく
new g_state[MAXPLAYERS1][8];
stock setState(client, no, value)
{
    g_state[client][no] = value;
}
stock any:getState(client, no)
{
    return g_state[client][no];
}
stock initStatus()
{
    new Float:time = GetGameTime();
    for (new i = 0; i < MAXPLAYERS+1; ++i) 
	{
        for (new j = 0; j < 8; ++j) 
		{
            g_delay[i][j] = time;
            g_state[i][j] = 0;
        }
    }
}

// 特殊がメイン攻撃した時間
new Float:g_si_attack_time;
stock any:getSIAttackTime()
{
        return g_si_attack_time;
}
stock updateSIAttackTime()
{
        g_si_attack_time = GetGameTime();
}

/**
 * TODO: 主攻撃の準備ができているか（リジャージ中じゃないか）調べたいけど
 *       どうすればいいのか分からない
 */
stock bool:readyAbility(client)
{
        /*
        new ability = GetEntPropEnt(client, Prop_Send, "m_customAbility");
        new String:name[256];
        GetClientName(client, name, 256);

        if (ability > 0) {
            //new Float:time = GetEntPropFloat(ability, Prop_Send, "m_timestamp");
                //new used = GetEntProp(ability, Prop_Send, "m_hasBeenUsed");
                //new Float:duration = GetEntPropFloat(ability, Prop_Send, "m_duration");
                return time < GetGameTime();
        } else {
                // なぜかここにくることがある
        }
        */
        return true;
}

// 入力がどうなっているの確認に使ってるやつ
stock debugPrint(client, buttons, Float:vel[3], Float:angles[3])
{
        // 条件でフィルタしないと出すぎてやばいので適当に書き換えてデバッグしてる
        if (IsFakeClient(client)) {
                return; // 自分だけ表示
        }

        new String:name[256];
        GetClientName(client, name, 256);

#if DEBUG_KEY
        // キー入力
        new String:command[1024];
        if (buttons & IN_DUCK) {
                StrCat(command, sizeof(command), "DUCK ");
        }
        if (buttons & IN_ATTACK) {
                StrCat(command, sizeof(command), "ATTACK ");
        }
        if (buttons & IN_ATTACK2) {
                StrCat(command, sizeof(command), "ATTACK2 ");
        }
        if (buttons & IN_MOVELEFT) {
                StrCat(command, sizeof(command), "MOVELEFT ");
        }
        if (buttons & IN_MOVERIGHT) {
                StrCat(command, sizeof(command), "MOVERIGHT ");
        }
        if (buttons & IN_FORWARD) {
                StrCat(command, sizeof(command), "FORWARD ");
        }
        if (buttons & IN_BACK) {
                StrCat(command, sizeof(command), "BACK ");
        }
        if (buttons & IN_USE) {
                StrCat(command, sizeof(command), "USE ");
        }
        if (buttons & IN_JUMP) {
                StrCat(command, sizeof(command), "JUMP ");
        }
        if (buttons != 0) {PrintToChatAll("%s: %s", name, command);}
#endif
#if DEBUG_ANGLE
        // angles
        PrintToChatAll("%s: angles(%f,%f,%f)", name, angles[0], angles[1], angles[2]);
#endif
#if DEBUG_VEL
        // vel
        if (vel[0] != 0.0 || vel[1] != 0.0) {
                PrintToChatAll("%s: vel(%f,%f,%f)", name, vel[0], vel[1], vel[2]);
        }
#endif
#if DEBUG_AIM
    // GetClientAimTargetで
        // AIMが向いてる方向にあるクライアントを取得後に
        // 見えてるか判定
        new entity = GetClientAimTarget(client, true);
        if (entity > 0) {
                new String:target[256];
                new visible = isVisibleTo(client, entity);
                // クライアントのエンティティ
                GetClientName(entity, target, 256);
                PrintToChatAll("%s aimed to %s (%s)", name, target, (visible ? "visible" : "invisible"));
        }
#endif
#if DEBUG_POS
        new Float:org[3], Float:eye[3];
        GetClientAbsOrigin(client, org);
        GetClientEyePosition(client, eye);
        PrintToChatAll("----");
        PrintToChatAll("AbsOrigin: (%f,%f,%f)", org[0], org[1], org[2]);
        PrintToChatAll("EyePosition: (%f,%f,%f)", eye[0], eye[1], eye[2]);
#endif
}

/**
 * 各クライアントの現在の移動速度を計算する
 *
 * g_move_speedは生存者が直線に走ったときが220くらい
 * 走っているとか止まっている判定できる
 */
new Float:g_move_grad[MAXPLAYERS1][3];
new Float:g_move_speed[MAXPLAYERS1];
new Float:g_pos[MAXPLAYERS1][3];
public Action:timerMoveSpeed(Handle:timer)
{
        for (new i = 1; i <= MaxClients; ++i) {
                if (IsClientInGame(i) && IsPlayerAlive(i)) {
                        new team = GetClientTeam(i);
                        if (team == 2 || team == 3) { // survivor or infected
                                new Float:pos[3];

                                GetClientAbsOrigin(i, pos);
                                g_move_grad[i][0] = pos[0] - g_pos[i][0];
                                 // yジャンプしてるときにおかしくなる..
                                g_move_grad[i][1] = pos[1] - g_pos[i][1];
                                g_move_grad[i][2] = pos[2] - g_pos[i][2];
                                // スピードに高さ方向は考慮しない
                                g_move_speed[i] =
                                        SquareRoot(g_move_grad[i][0] * g_move_grad[i][0] +
                                                           g_move_grad[i][1] * g_move_grad[i][1]);
                                if (g_move_speed[i] > MOVESPEED_MAX) {
                                        // ワープやリスポンしたっぽいときはクリア
                                        g_move_speed[i] = 0.0;
                                        g_move_grad[i][0] = 0.0;
                                        g_move_grad[i][1] = 0.0;
                                        g_move_grad[i][2] = 0.0;
                                }
                                g_pos[i] = pos;
#if DEBUG_SPEED
                                if (!IsFakeClient(i)) {
                                        // 俺
                                        PrintToChat(i, "speed: %f(%f,%f,%f)",
                                                                g_move_speed[i],
                                                                g_move_grad[i][0], g_move_grad[i][1], g_move_grad[i][2]
                                                );
                                }
#endif
                        }
                }
        }
        return Plugin_Continue;
}

stock Float:getMoveSpeed(client)
{
        return g_move_speed[client];
}
stock Float:getMoveGradient(client, ax)
{
        return g_move_grad[client][ax];
}

public bool:traceFilter(entity, mask, any:self)
{
        return entity != self;
}

/* clientからtargetの頭あたりが見えているか判定 */
stock bool:isVisibleTo(client, target)
{
        new bool:ret = false;
        new Float:angles[3];
        new Float:self_pos[3];

        GetClientEyePosition(client, self_pos);
        computeAimAngles(client, target, angles);
        new Handle:trace = TR_TraceRayFilterEx(self_pos, angles, MASK_SOLID, RayType_Infinite, traceFilter, client);
        if (TR_DidHit(trace)) {
                new hit = TR_GetEntityIndex(trace);
                if (hit == target) {
                        ret = true;
                }
        }
        CloseHandle(trace);
        return ret;
}
// clientからtargetへのアングルを計算
stock computeAimAngles(client, target, Float:angles[3], AimTarget:type = AimTarget_Eye)
{
        new Float:target_pos[3];
        new Float:self_pos[3];
        new Float:lookat[3];

        GetClientEyePosition(client, self_pos);
        switch (type) {
        case AimTarget_Eye: {
                GetClientEyePosition(target, target_pos);
        }
        case AimTarget_Body: {
                GetClientAbsOrigin(target, target_pos);
        }
        case AimTarget_Chest: {
                GetClientAbsOrigin(target, target_pos);
                target_pos[2] += 45.0; // このくらい
        }
        }
        MakeVectorFromPoints(self_pos, target_pos, lookat);
        GetVectorAngles(lookat, angles);
}
// 生存者の場合ダウンしてるか？
stock bool:isIncapacitated(client)
{
    new bool:bIsIncapped = false;
	if ( IsSurvivor(client) ) {
		if (GetEntProp(client, Prop_Send, "m_isIncapacitated") > 0) bIsIncapped = true;
		if (!IsPlayerAlive(client)) bIsIncapped = true;
	}
	return bIsIncapped;
}
stock bool:hasPinned(client) {
	new bool:bhasPinned = false;
	if (IsSurvivor(client)) {
		// check if held by:
		if( GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0 ) bhasPinned = true; // hunter
		if( GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0 ) bhasPinned = true; // charger pound
		if( GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0 ) bhasPinned = true; // charger carry
	}		
	return bhasPinned;
}
stock L4D2_RunScript(const String:sCode[], any:...)
{
	static iScriptLogic = INVALID_ENT_REFERENCE;
	if(iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic)) {
		iScriptLogic = EntIndexToEntRef(CreateEntityByName("logic_script"));
		if(iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic))
			SetFailState("Could not create 'logic_script'");
		
		DispatchSpawn(iScriptLogic);
	}
	
	static String:sBuffer[512];
	VFormat(sBuffer, sizeof(sBuffer), sCode, 2);
	
	SetVariantString(sBuffer);
	AcceptEntityInput(iScriptLogic, "RunScriptCode");
}