/*
 * L4D2�����Ⱦ��BOT�Υץ쥤��������򥫥����ޥ�������g�Y�Ĥʥץ饰����
 *
 * ���F���������Ⱦ��BOT��2/3�Τ����ĉ䤷�ޤ�
 *
 * ���`�����򥷥ߥ��`�Ȥ��뤳�Ȥ�BOT��������뤿��
 * �����ƥ�ϥǥե���ȤΤޤ�!!
 *
 *   addons/sourcemod/scripting
 * �ˤ�����
 *   ./compile.sh l4d2_asiai.sp
 * �ǥ���ѥ���
 *   cp ./compiled/l4d2_asiai.smx ../plugins
 * �ǥ��󥹥ȩ`��
 *
 * ./srcds_run -nomaster -game left4dead2 +sv_gametypes "community1" +mp_gamemode "community1" +map "c2m1_highway community1"
 *
 * ��Special Delivary�Υ��`�Щ`�����Ӥ��ƽӾA������`�����֤���䤹����˼���ޤ�
 */
#include <sourcemod>
#include <sdktools>
//#include <sdkhooks>

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
        CreateConVar("asiai_version", "0.1", "Advanced Special Infected AI Version", FCVAR_NONE|FCVAR_NOTIFY|FCVAR_REPLICATED|FCVAR_DONTRECORD);
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
        if (isSpecialInfectedBot(client)) {
                // AI�m�ä��Є��o�����Ф��椨�루���󥯤Ϥ��Υե饰��oҕ���룩
                
                        // 2/3�����ĉ�
                        g_ai_enable[client] = true;
        }
}

/* ���饤����ȤΥ��`�����I��
 *
 * ������bot�Υ��`������Oҕ���ƕ����Q���뤳�Ȥ�bot�򥳥�ȥ�`�뤹��
 *
 * buttons: �������줿���` (enum��include/entity_prop_stock.inc����)
 * vel: �ץ�`��`���ٶȣ�
 *      �g�ץ�`��`����
 *      [0]������������-450��+450.
 *      [1]������������-450��+450.
 *      bot����230
 *
 * angles: ҕ���η���(�ޥ������`������򤱤Ƥ��뷽��)��
 *      [0]��pitch(����) -89��+89
 *      [1]��yaw(�Է֤����Ĥ�360�Ȼ�ܞ) -180��+180
 *
 *      ����������Ƥ�ҕ���ω���ʤ���IN_FORWARD�ˌ������Ƅӷ��򤬉���
 *
 * impulse: impules command �ʤ�
 *
 * buttons, vel, angles�ϕ����Q����Plugin_Changed�򷵤��в����˷�ӳ�����.
 * �����I��혤Ά��}�����äƤ��Ȥ���IN_USE�ΥӥåȤ���Ȥ���USE Key��ʹ���ʤ��褦�ˤ����
 * ������ȡ��ʤ����ɥɥ����_���ߤ������¤��𤳤ꤨ��.
 *
 * ���`��ե�`�फ����Ф��褦�ʤΤǤǤ�������X���I��ˤ���.
 */
public Action:OnPlayerRunCmd(client, &buttons, &impulse,
                                                         Float:vel[3], Float:angles[3], &weapon)
{
        // �_�J��...
#if (DEBUG_SPEED || DEBUG_KEY || DEBUG_EYE || DEBUG_ANGLE || DEBUG_VEL || DEBUG_AIM || DEBUG_POS)
        debugPrint(client, buttons, vel, angles);
#endif
        // �����BOT�Τ߄I��
        if (isSpecialInfectedBot(client)) {
                // versus���ȥ��`����״�B��Bot�����뤱��
                // Coop���ȥ��`���Ȥʤ��Ǥ����ʤ�Ф��Ƥ�?
                // ��إ��`���ȤϿ��]���ʤ�
                if (!isGhost(client)) {
                        // �N��Ȥ΄I��
                        new zombie_class = getZombieClass(client);
                        new Action:ret = Plugin_Continue;

                        if (zombie_class == ZC_TANK) {
                                ret = onTankRunCmd(client,  buttons, vel, angles);
                        } else if (g_ai_enable[client]) {
                                switch (zombie_class) {
                                case ZC_SMOKER: { ret = onSmokerRunCmd(client, buttons, vel, angles); }
                                case ZC_HUNTER: { ret = onHunterRunCmd(client, buttons, vel, angles); }
                                case ZC_JOCKEY: { ret =  onJockeyRunCmd(client, buttons, vel, angles); }
                                case ZC_BOOMER: { ret = onBoomerRunCmd(client, buttons, vel, angles); }
                                case ZC_SPITTER: { ret = onSpitterRunCmd(client, buttons, vel, angles); }
                                case ZC_CHARGER: { ret = onChargerRunCmd(client, buttons, vel, angles); }
                                }
                        }
                        // ����Υᥤ�󹥓ĕr�g�򱣴�
                        if (buttons & IN_ATTACK) {
                                updateSIAttackTime();
                        }
                        return ret;
                }
        }
        return Plugin_Continue;
}

/**
 * ����`���`�΄I��
 *
 * ����󥹤����������w�Ф�
 */
#define SMOKER_ATTACK_SCAN_DELAY     0.5
#define SMOKER_ATTACK_TOGETHER_LIMIT 5.0
#define SMOKER_MELEE_RANGE           300.0
stock Action:onSmokerRunCmd(client, &buttons, Float:vel[3], Float:angles[3])
{
        static Float:s_tounge_range = -1.0;
        new Action:ret = Plugin_Continue;

        if (s_tounge_range < 0.0) {
                // �ब�줯����
                s_tounge_range = GetConVarFloat(FindConVar("tongue_range"));
        }
        if (buttons & IN_ATTACK) {
                // bot�Υȥꥬ�`�Ϥ��ΤޤބI���� ��ԭ����������˴�����
        } else if (delayExpired(client, 0, SMOKER_ATTACK_SCAN_DELAY)
                           && GetEntityMoveType(client) != MOVETYPE_LADDER)
        {
                delayStart(client, 0);
                /* ����SI�����Ĥ��Ƥ��뤫���`���åȤ���AIM���ܤ��Ƥ�����Ϥ�
                   �ब�줯���x�˥��`���åȤ������鼴���Ĥ��� �����һ��SI���ڹ������������Ŀ���AIM
??????????????????? ���Ŀ������ͷ�ɼ��ķ�Χ�ڣ��������й���**/

                // bot�����`���åȤ��Ƥ��������ߤ�ȡ�� ��ȡ��������׼���Ҵ���
                new target = GetClientAimTarget(client, true);
                if (target > 0 && isSurvivor(target) && isVisibleTo(client, target)) {
                        // �����ߤ�Ҋ���Ƥ��� ��������Ҵ���
                        new Float:target_pos[3];
                        new Float:self_pos[3];
                        new Float:dist;

                        GetClientAbsOrigin(client, self_pos);
                        GetClientAbsOrigin(target, target_pos);
                        // ���`���åȤȤξ��x��Ӌ�� ���㵽Ŀ��ľ���
                        dist = GetVectorDistance(self_pos, target_pos);
                        if (dist < SMOKER_MELEE_RANGE) {
                                // ���`���åȤȽ���������Ϥ⤦����ʤΤǼ����Ĥ��� �������Ŀ��̫�������޷��ٽ��й���
                                buttons |= IN_ATTACK|IN_ATTACK2; // �ब�ʤ����Ȥ�����Τ�Ź��������ҿ��Ի���������Ϊû����ͷ
                                ret = Plugin_Changed;
                        } else if (dist < s_tounge_range) {
                                // �ब�줯����˥��`���åȤ�������� ��Ŀ�괥����ͷʱ
                                if (GetGameTime() - getSIAttackTime() < SMOKER_ATTACK_TOGETHER_LIMIT) {
                                        // ���SI�����Ĥ��Ƥ������󥹤äݤ��ΤǼ����Ĥ��� ���SI����ܵ����������ƺ���һ�λ��ᣬ������������й���
                                        buttons |= IN_ATTACK;
                                        ret = Plugin_Changed;
                                } else {
                                        new target_aim = GetClientAimTarget(target, true);
                                        if (target_aim == client) {
                                                // ���`���åȤ����ä���AIM���򤱤Ƥ��鼴���Ĥ��� ���Ŀ�꽫AIMָ��˴������������𹥻�
                                                buttons |= IN_ATTACK;
                                                ret = Plugin_Changed;
                                        }
                                }
                                // ����bot���Τ��� �������뿪������
                        }
                }
        }

        return ret;
}

/**
 * ����å��`�΄I��
 *
 * ���ޤ˥����פ���Τ������ߤν����ǻĤ֤�
 */
#define JOCKEY_JUMP_DELAY 2.0
#define JOCKEY_JUMP_NEAR_DELAY 0.1
#define JOCKEY_JUMP_NEAR_RANGE 400.0 // ���ι���������ߤ�������Ĥ֤�
#define JOCKEY_JUMP_MIN_SPEED 130.0
stock Action:onJockeyRunCmd(client, &buttons, Float:vel[3], Float:angles[3])
{

        if (
                // �ٶȤ��Ĥ��Ƥơ����������������Ϥ�
                // �ϥ����Ф���ʤ��Ȥ��Ϥ��ޤ˥����פ���
                // ����������ߤ����ʤ�����ˤ���Ȥ����w�����ͤޤ���
                (getMoveSpeed(client)  > JOCKEY_JUMP_MIN_SPEED
                 && (buttons & IN_FORWARD)
                 && (GetEntityFlags(client) & FL_ONGROUND)
                 && GetEntityMoveType(client) != MOVETYPE_LADDER)
                && ((nearestSurvivorDistance(client) < JOCKEY_JUMP_NEAR_RANGE
                         && delayExpired(client, 0, JOCKEY_JUMP_NEAR_DELAY))
                        || delayExpired(client, 0, JOCKEY_JUMP_DELAY)))
        {
                // �����פ��w�Ӂ\��(PrimaryAttack)�򽻻����R�귵��
                vel[0] = VEL_MAX;
                if (getState(client, 0) == IN_JUMP) {
                        // �ϤΤۤ����w�Ӂ\��Ӥ��򤹤� ���Ϸ�Ծ
                        // angles�������Ƥ�ҕ�����Ӥ��ʤ��Τ� ��ʹ�ı�Ƕȣ�����Ҳ���ᶯ
                        // TeleportEntity��ҕ���������� ��TeleportEntity�ı�����

                        // �Ϸ���(����̶ȥ�����)��ҕ������ ���ϸı����ߣ��е����⣩
                        if (angles[2] == 0.0) {
                                angles = angles;
                                angles[0] = GetRandomFloat(-50.0,-10.0);
                                TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
                        }
                        // �w�Ӂ\��
                        buttons |= IN_ATTACK;
                        setState(client, 0, IN_ATTACK);
                } else {
                        // ͨ�������� ������Ծ
                        // Ź�ꥸ���� ����
                        // ���å������� // ���㤬��Ѻ���äѤʤ��ˤ��ʤ��ȤǤ��ʤ����⣿ ����//��������²��ƶ����������� ���ʹ��
                        // ��������ʹ��
                        if (angles[2] == 0.0) {
                                angles[0] = GetRandomFloat(-10.0, 0.0);
                                TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
                        }
                        buttons |= IN_JUMP;
                        switch (GetRandomInt(0, 2)) {
                        case 0: { buttons |= IN_DUCK; }
                        case 1: { buttons |= IN_ATTACK2; }
                        }
                        setState(client, 0, IN_JUMP);
                }
                delayStart(client, 0);
                return Plugin_Changed;
        }
        return Plugin_Continue;
}

/**
 * ����`����`�΄I��
 *
 * �ʤ���ޤ���
 */
#define CHARGER_MELEE_DELAY     0.2
#define CHARGER_MELEE_RANGE 400.0
stock Action:onChargerRunCmd(client, &buttons, Float:vel[3], Float:angles[3])
{
        // �ϥ���������������߽����ˤ���Ȥ� �����������ϵ��Ҵ���ʱ
        if (!(buttons & IN_ATTACK)
                && GetEntityMoveType(client) != MOVETYPE_LADDER
                && (GetEntityFlags(client) & FL_ONGROUND)
                && delayExpired(client, 0, CHARGER_MELEE_DELAY)
                && nearestSurvivorDistance(client) < CHARGER_MELEE_RANGE)
        {
                // �m�����g����Ź��򤤤�� ���ʵ��ļ������
                delayStart(client, 0);
                buttons |= IN_ATTACK2;
                return Plugin_Changed;
        }
        return Plugin_Continue;
}

/**
 * �ϥ󥿩`�΄I��
 *
 * �ΤΤ褦�ˤ���
 * - ������w�Ӓ��Υȥꥬ�`��BOT���԰k�Ĥ��Ф�
 * - BOT���w�Ӓ�ä���һ�����g���ĥ�`�ɤ�ON�ˤ���
 * - ���ĥ�`�ɤ�ON�Έ��Ϥ��ޤ��ޤʽǶȤ��B�A�Ĥ��w�Ӥޤ���Ӥ���
 *   ���`���åȤ�Ѥä��w�Ӥ����꣨�ǥե���Ȥ΄Ӥ�����줼���w�ӻؤ�
 *
 * ���� hunter_pounce_ready_range �Ȥ���CVAR���2000���餤�ˉ�������
 * �h���ˤ���Ȥ��Ǥ⤷�㤬��褦�ˤʤ�Ή������Ȥ褤
 *
 * ���ȓĤ��줿�Ȥ��������w����Ӥ���äݤ��Ӥ������Ф���Τ��ᤵ������
 ���˴���
 *
 *��ִ�����²���
 * -BOT�Է�������һ��
 * -BOT��Ծʱ��һ��ʱ���ڿ�������ģʽ
 *-��������ģʽʱ�������Ը��ֽǶ��������С�
 *��Ŀ����Χ������ȥ��Ĭ���ƶ���
 *
 *��hunter_pounce_ready_range CVAR����Ϊ2000֮��
 *��ʹ�ں�Զ�ĵط�Ҳ���Զ���
 *
 *��Ҫֹͣ�ص����ڻص�ʱ����
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
        new Action:ret = Plugin_Continue;
        new bool:internal_trigger = false;

        if (!delayExpired(client, 1, HUNTER_ATTACK_TIME)
                && GetEntityMoveType(client) != MOVETYPE_LADDER)
        {
                // ���ĥ�`���Ф�DUCKѺ���äѤʤ�����ATTACK�B�򤹤� �ڹ���ģʽ�°�סDUCK����������ATTACK
                buttons |= IN_DUCK;
                if (GetRandomInt(0, HUNTER_REPEAT_SPEED) == 0) {
                        // ATTACK���x���ʤ��Ȅ������ʤ��Τ� �����ͷ���������ATTACK��Ч
                        // ��������g����Ѻ����״�B������ ����������������״̬
                        buttons |= IN_ATTACK;
                        internal_trigger = true;
                }
                ret = Plugin_Changed;
        }
        if (!(GetEntityFlags(client) & FL_ONGROUND)
                && getState(client, HUNTER_STATE_FLY_FLAG) == 0)
        {
                // �������_ʼ ���ٿ�ʼ
                delayStart(client, 2);
                setState(client, HUNTER_STATE_FALL_FLAG, 0);
                setState(client, HUNTER_STATE_FLY_FLAG, 1);
        } else if (!(GetEntityFlags(client) & FL_ONGROUND)) {
                // ���Фˤ������ ������ڿ���
                if (getState(client, HUNTER_STATE_FLY_TYPE) == IN_FORWARD) {
                        // �ǶȤ�䤨���w�֤Ȥ��Ͽ��Фǡ����������� ���Բ�ͬ�Ƕȷ���ʱ���ڿ������������
                        buttons |= IN_FORWARD;
                        vel[0] = VEL_MAX;
                        if (getState(client, HUNTER_STATE_FALL_FLAG) == 0
                                && delayExpired(client, 2, HUNTER_FALL_DELAY))
                        {
                                // �w��ʼ��Ƥ����٤�����ҕ����䤨�� ��ʼ���к���΢�ı�һ���۾�
                                if (angles[2] == 0.0) {
                                        angles[0] = GetRandomFloat(-50.0, 20.0);
                                        TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
                                }
                                setState(client, HUNTER_STATE_FALL_FLAG, 1);
                        }
                        ret = Plugin_Changed;
                }
        } else if (getState(client, 2) == 1) {
                // �ŵ�
        } else {
                setState(client, HUNTER_STATE_FLY_FLAG, 0);
        }
        if (delayExpired(client, 0, HUNTER_FLY_DELAY)
                && (buttons & IN_ATTACK)
                && (GetEntityFlags(client) & FL_ONGROUND))
        {
                // �w�Ӥ������_ʼ ��ʼ��Ծ
                new Float:dist = nearestSurvivorDistance(client);

                delayStart(client, 0);
                if (!internal_trigger
                        && !(buttons & IN_BACK)
                        && dist < HUNTER_NEAR_RANGE
                        && delayExpired(client, 1, HUNTER_ATTACK_TIME + HUNTER_COOLDOWN_DELAY))
                {
                        // BOT���ȥꥬ�`�����������ߤ˽������ϤϹ��ĥ�`�ɤ����Ф��� ���BOT�����������Ҵ��ߣ�����빥��ģʽ
                        delayStart(client, 1); // ����delay���Ф��ޤǹ��ĥ�`�� ����ģʽ��ֱ�����ӳٵ���
                }
                // ��������w�ӷ���
                //���`���åȤ�Ѥä��ǥե���Ȥ��w�ӷ����������R�귵��.�������//����ظ���׼Ŀ���Ĭ�Ϸ�ʽ��
                if (GetRandomInt(0, 1) == 0) {
                        // ��������w�� �����
                        if (dist < HUNTER_NEAR_RANGE) {
                                if (angles[2] == 0.0) {
                                        if (GetRandomInt(0, 4) == 0) {
                                                // �ߤ���w�� 1/5 �ɸ�1/5vc
                                                angles[0] = GetRandomFloat(-50.0, -30.0);
                                        } else {
                                                // �ͤ���w��
                                                angles[0] = GetRandomFloat(-10.0, 20.0);
                                        }
                                        // ҕ������
                                        TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
                                }
                                // ���Ф�ǰ����������ե饰�򥻥å�
                                setState(client, HUNTER_STATE_FLY_TYPE, IN_FORWARD);
                        } else {
                                // �ǥե���Ȥ��w�Ӓ��
                                setState(client, HUNTER_STATE_FLY_TYPE, 0);
                        }
                } else {
                        // �ǥե���Ȥ��w�Ӓ��
                        setState(client, HUNTER_STATE_FLY_TYPE, 0);
                }
                ret = Plugin_Changed;
        }

        return ret;
}

/**
 * �֩`�ީ`�΄I��
 *
 * Coop�֩`�ީ`�Ϸe�O�Ĥ˥�����¤��ʤ��Ȥ�����
 * ����Υ����`�����Ǥ��Ƥ��ʤ����Ȥ����룿��Ҫ�_�J��
 * �ǥ������Ƥ�������ʤΤ�
 * ���������줽���ʤ鼴������褦�ˤ���
 */
#define BOMMER_SCAN_DELAY 0.5
stock Action:onBoomerRunCmd(client, &buttons, Float:vel[3], Float:angles[3])
{
        static Float:s_vomit_range = -1.0;
        if (s_vomit_range < 0.0) {
                // ������w���x
                s_vomit_range = GetConVarFloat(FindConVar("z_vomit_range"));
        }
        if (buttons & IN_ATTACK) {
                // BOT�Υȥꥬ�`�ϟoҕ���� ����BOT������
                buttons &= ~IN_ATTACK;
                return Plugin_Changed;
        } else if (delayExpired(client, 0, BOMMER_SCAN_DELAY)
                && GetEntityMoveType(client) != MOVETYPE_LADDER)
        {
                delayStart(client, 0);
                // �����줯���x�˥��`���åȤ�����ФȤˤ���������
                new target = GetClientAimTarget(client, true);
                if (target > 0 && isSurvivor(target) && isVisibleTo(client, target)) {
                        new Float:target_pos[3];
                        new Float:self_pos[3];
                        new Float:dist;

                        GetClientAbsOrigin(client, self_pos);
                        GetClientAbsOrigin(target, target_pos);
                        dist = GetVectorDistance(self_pos, target_pos);
                        if (dist < s_vomit_range) {
                                buttons |= IN_ATTACK;
                                return Plugin_Changed;
                        }
                }
        }

        return Plugin_Continue;
}

/**
 * ���ԥå��`�΄I��
 *
 * ���ԥå��`�Ϥʤ��ؤ���ζ�ʤ������פ����ꤹ��
 */
#define SPITTER_RUN 200.0
#define SPITTER_SPIT_DELAY 2.0
#define SPITTER_JUMP_DELAY 0.1
stock Action:onSpitterRunCmd(client, &buttons, Float:vel[3], Float:angles[3])
{
        if (getMoveSpeed(client) > SPITTER_RUN
                && delayExpired(client, 0, SPITTER_JUMP_DELAY)
                && (GetEntityFlags(client) & FL_ONGROUND))
        {
                // �Ӥ��Ƥ�äݤ��Ȥ������פ���
                delayStart(client, 0);
                buttons |= IN_JUMP;
                if (getState(client, 0) == IN_MOVERIGHT) {
                        setState(client, 0, IN_MOVELEFT);
                        buttons |= IN_MOVERIGHT;
                        vel[1] = VEL_MAX;
                } else {
                        setState(client, 0, IN_MOVERIGHT);
                        buttons |= IN_MOVELEFT;
                        vel[1] = -VEL_MAX;
                }
                return Plugin_Changed;
        }

        if (buttons & IN_ATTACK) {
                // �¤��Ȥ��Ĥ��Ǥ˥����פ���
                if (delayExpired(client, 1, SPITTER_SPIT_DELAY)) {
                        delayStart(client, 1);
                        buttons |= IN_JUMP;
                        return Plugin_Changed;
                        // �¤��ǶȤ�䤨��������
                        // ҕ�������Ϥ�teleport�����Ƥ����¤��Ƥ�
                        // ����Ǥ��ʤ��ä� TODO
                }
        }

        return Plugin_Continue;
}

/**
 * ���󥯤΄I��
 *
 * - �����������ߤ�����ФȤˤ���Ź��
 * - �ߤäƤ���Ȥ���ֱ���Ĥʥ����פǼ��٤���
 * - ��Ͷ���Ф˥��`���åȤ��Ƥ����ˤ�Ҋ���ʤ��ʤä��饿�`���åȤ�������
 *   ��Ͷ����˲�g�˥��`���åȤ�����ȥ�`�������`��܉����Ͷ���룩
 ���Ŀ������ʯͷʱ��ʧ�ˣ������Ŀ��
 *�����Ŀ����Ͷ��ʱ�����仯������˶���Ͷ������ͬ�Ĺ켣��
 */
#define TANK_MELEE_SCAN_DELAY 0.5
#define TANK_BHOP_SCAN_DELAY  2.0
#define TANK_BHOP_TIME        1.6
#define TANK_ROCK_AIM_TIME    4.0
#define TANK_ROCK_AIM_DELAY   0.25
stock Action:onTankRunCmd(client, &buttons, Float:vel[3], Float:angles[3])
{
        static Float:s_tank_attack_range = -1.0;
        static Float:s_tank_speed = -1.0;

        if (s_tank_attack_range < 0.0) {
                // Ź��ι���
                s_tank_attack_range = GetConVarFloat(FindConVar("tank_attack_range"));
        }
        if (s_tank_speed < 0.0) {
                // ���󥯤��٤�
                s_tank_speed = GetConVarFloat(FindConVar("z_tank_speed"));
        }
        // ��Ͷ�� ��ʯͷ
        if ((buttons & IN_ATTACK2)) {
                // BOT����Ͷ���_ʼ
                // ���Εr�g���Ф��ޤǥ��`���åȤ�̽����AutoAim����
                delayStart(client, 3);
                delayStart(client, 4);
        }
        // ��Ͷ����
        if (delayExpired(client, 4, TANK_ROCK_AIM_DELAY)
                && !delayExpired(client, 3, TANK_ROCK_AIM_TIME))
        {
                new target = GetClientAimTarget(client, true);
                if (target > 0 && isVisibleTo(client, target)) {
                        // BOT���ѤäƤ��륿�`���åȤ�Ҋ���Ƥ������  ��BOT��׼��Ŀ��ɼ�ʱ
                } else {
                        // Ҋ���Ɵo�����Ϥϥ��󥯤���Ҋ���빠���һ�����������ߤ���� ������ǣ�����ս���ɼ���Χ��Ѱ����ӽ����Ҵ���
                        new new_target = -1;
                        new Float:min_dist = 100000.0;
                        new Float:self_pos[3], Float:target_pos[3];

                        GetClientAbsOrigin(client, self_pos);
                        for (new i = 1; i <= MaxClients; ++i) {
                                if (isSurvivor(i)
                                        && IsPlayerAlive(i)
                                        && !isIncapacitated(i)
                                        && isVisibleTo(client, i))
                                {
                                        new Float:dist;

                                        GetClientAbsOrigin(i, target_pos);
                                        dist = GetVectorDistance(self_pos, target_pos);
                                        if (dist < min_dist) {
                                                min_dist = dist;
                                                new_target = i;
                                        }
                                }
                        }
                        if (new_target > 0) {
                                // �¤��ʥ��`���åȤ��՜ʤ�Ϥ碌�� ��׼��Ŀ��
                                if (angles[2] == 0.0) {
                                        new Float:aim_angles[3];
                                        computeAimAngles(client, new_target, aim_angles, AimTarget_Chest);
                                        aim_angles[2] = 0.0;
                                        TeleportEntity(client, NULL_VECTOR, aim_angles, NULL_VECTOR);
                                        return Plugin_Changed;
                                }
                        }
                }
        }

        // Ź��
        if (GetEntityMoveType(client) != MOVETYPE_LADDER
                && (GetEntityFlags(client) & FL_ONGROUND)
                && IsPlayerAlive(client))
        {
                if (delayExpired(client, 0, TANK_MELEE_SCAN_DELAY)) {
                        // Ź��ε����빠������äƤ��������ߤ������鷽����v�S�ʤ�Ź�� ������Ҵ���վ����Ϯ�������κη���ײ��
                        delayStart(client, 0);
                        if (nearestActiveSurvivorDistance(client) < s_tank_attack_range * 0.95) {
                                buttons |= IN_ATTACK;
                                return Plugin_Changed;
                        }
                }
        }

        // ���٥�����
        if (delayExpired(client, 1, TANK_BHOP_SCAN_DELAY)
                && delayExpired(client, 2, TANK_BHOP_TIME)
                && GetEntityMoveType(client) != MOVETYPE_LADDER
                && (GetEntityFlags(client) & FL_ONGROUND)
                && getMoveSpeed(client) > s_tank_speed * 0.9)
        {
                // 90%���ϤΥ��ԩ`�ɤ����Ƥ���������_ʼ
                delayStart(client, 1);
                delayStart(client, 2);
        }
        if (!delayExpired(client, 2, TANK_BHOP_TIME)
                && getMoveSpeed(client) > s_tank_speed * 0.85
                && GetEntityMoveType(client) != MOVETYPE_LADDER)
        {
                // ���٥�����
                // ���`���������Ϝp�٤��Ƥ��ޤ��Τ�ʹ�碌�ʤ�����
                // ͨ���^���Ƥ��ޤ����Ȥ�����..
                buttons &= ~(IN_FORWARD|IN_BACK|IN_MOVELEFT|IN_MOVERIGHT);
                vel[0] = 0.0;
                vel[1] = 0.0;
                if ((GetEntityFlags(client) & FL_ONGROUND)) {
                        buttons |= IN_JUMP|IN_DUCK;
                } else {
                        buttons &= ~(IN_DUCK|IN_JUMP);
                }
                return Plugin_Changed;
        }

        return Plugin_Continue;
}

// client��һ�������ˤ��������ߤξ��x��ȡ��
//
// ��ϥȥ�`�����Ƥ��ʤ��Τ�1�A��2�A�Ȥ��O�β��ݤȤ�
//��ȡ�Ҵ�����ͻ�����ľ���
//
//�����ڲ�׷�٣�����һ¥�Ͷ�¥�Լ���һ������
//��ʹ���ϰ�ҲҪ����
// �ڤ��Τ����äƤ�����ˤʤäƤ��ޤ�
stock any:nearestSurvivorDistance(client)
{
        new Float:self[3];
        new Float:min_dist = 100000.0;

        GetClientAbsOrigin(client, self);
        for (new i = 1; i <= MaxClients; ++i) {
                if (IsClientInGame(i) && isSurvivor(i) && IsPlayerAlive(i)) {
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
                        && !isIncapacitated(client))
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

// client����Ҋ���빠���һ�����������ߤ�ȡ��
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
                        && isVisibleTo(client, i))
                {
                        new Float:target[3];
                        GetClientAbsOrigin(i, target);
                        new Float:dist = GetVectorDistance(self, target);
                        if (dist < min_dist) {
                                min_dist = dist;
                                min_i = i;
                        }
                }
        }
        return min_i;
}

// ��Ⱦ�ߤ�
stock bool:isInfected(i)
{
        return GetClientTeam(i) == 3;
}
// ���`���Ȥ�
stock bool:isGhost(i)
{
        return isInfected(i) && GetEntProp(i, Prop_Send, "m_isGhost");
}
// �����Ⱦ�ߥܥåȤ�
stock bool:isSpecialInfectedBot(i)
{
        return i > 0 && i <= MaxClients && IsClientInGame(i) && IsFakeClient(i) && isInfected(i);
}
// �����ߤ�
// ����Ǥ�Ȥ������󤷤Ƥ�Ȥ���������Ƥ�Ȥ���Ҋ���ۤ��������Ǥ��礦..
stock bool:isSurvivor(i)
{
        return i > 0 && i <= MaxClients && IsClientInGame(i) && GetClientTeam(i) == 2;
}
// ��Ⱦ�ߤηN�ȡ��
stock any:getZombieClass(client)
{
        return GetEntProp(client, Prop_Send, "m_zombieClass");
}

/**
 * ���`�����I���ڤǥӥ��`��`�פ�״�B�S�֤�ʹ�äƤ������
 *
 * ������Ȥ��˥��ꥢ���ʤ���ǰ����󤬲ФäƤ뤱��
 * ���ޤ�ݤˤʤ�ʤ��褦������ˤ��Ƥ�
 */
// 1 client 8delay��֤äȤ�
new Float:g_delay[MAXPLAYERS1][8];
stock delayStart(client, no)
{
        g_delay[client][no] = GetGameTime();
}
stock bool:delayExpired(client, no, Float:delay)
{
        return GetGameTime() - g_delay[client][no] > delay;
}
// 1 player 8state ��֤äȤ�
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
        for (new i = 0; i < MAXPLAYERS+1; ++i) {
                for (new j = 0; j < 8; ++j) {
                        g_delay[i][j] = time;
                        g_state[i][j] = 0;
                }
        }
}

// ���⤬�ᥤ�󹥓Ĥ����r�g
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
 * TODO: �����ĤΜʂ䤬�Ǥ��Ƥ��뤫���ꥸ��`���Ф���ʤ������{�٤�������
 *       �ɤ�����Ф����Τ��֤���ʤ�
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
                // �ʤ��������ˤ��뤳�Ȥ�����
        }
        */
        return true;
}

// �������ɤ��ʤäƤ���δ_�J��ʹ�äƤ���
stock debugPrint(client, buttons, Float:vel[3], Float:angles[3])
{
        // �����ǥե��륿���ʤ��ȳ������Ƥ�Ф��Τ��m���˕����Q���ƥǥХå����Ƥ�
        if (IsFakeClient(client)) {
                return; // �Է֤�����ʾ
        }

        new String:name[256];
        GetClientName(client, name, 256);

#if DEBUG_KEY
        // ���`����
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
    // GetClientAimTarget��
        // AIM���򤤤Ƥ뷽��ˤ��륯�饤����Ȥ�ȡ�����
        // Ҋ���Ƥ뤫�ж�
        new entity = GetClientAimTarget(client, true);
        if (entity > 0) {
                new String:target[256];
                new visible = isVisibleTo(client, entity);
                // ���饤����ȤΥ���ƥ��ƥ�
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
 * �����饤����ȤάF�ڤ��Ƅ��ٶȤ�Ӌ�㤹��
 *
 * g_move_speed�������ߤ�ֱ�����ߤä��Ȥ���220���餤
 * �ߤäƤ���Ȥ�ֹ�ޤäƤ����ж��Ǥ���
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
                                 // y�����פ��Ƥ�Ȥ��ˤ��������ʤ�..
                                g_move_grad[i][1] = pos[1] - g_pos[i][1];
                                g_move_grad[i][2] = pos[2] - g_pos[i][2];
                                // ���ԩ`�ɤ˸ߤ�����Ͽ��]���ʤ�
                                g_move_speed[i] =
                                        SquareRoot(g_move_grad[i][0] * g_move_grad[i][0] +
                                                           g_move_grad[i][1] * g_move_grad[i][1]);
                                if (g_move_speed[i] > MOVESPEED_MAX) {
                                        // ��`�פ�ꥹ�ݥ󤷤��äݤ��Ȥ��ϥ��ꥢ
                                        g_move_speed[i] = 0.0;
                                        g_move_grad[i][0] = 0.0;
                                        g_move_grad[i][1] = 0.0;
                                        g_move_grad[i][2] = 0.0;
                                }
                                g_pos[i] = pos;
#if DEBUG_SPEED
                                if (!IsFakeClient(i)) {
                                        // ��
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

/* client����target���^�����꤬Ҋ���Ƥ��뤫�ж� */
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

// client����target�ؤΥ��󥰥��Ӌ��
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
                target_pos[2] += 45.0; // ���Τ��餤
        }
        }
        MakeVectorFromPoints(self_pos, target_pos, lookat);
        GetVectorAngles(lookat, angles);
}
// �����ߤΈ��ϥ����󤷤Ƥ뤫��
stock bool:isIncapacitated(client)
{
        return isSurvivor(client)
                && GetEntProp(client, Prop_Send, "m_isIncapacitated", 1) == 1
}