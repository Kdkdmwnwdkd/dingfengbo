// 敌人 AI(晋朝武士)
// 状态机:巡逻 → 警戒 → 追击 → 攻击 → 受击 → 死亡
// NavMeshAgent + Animator 驱动
using System.Collections;
using UnityEngine;
using UnityEngine.AI;
using Dingfengbo.Player;

namespace Dingfengbo.Enemy
{
    [RequireComponent(typeof(NavMeshAgent))]
    public class EnemyAI : MonoBehaviour, IDamageable
    {
        public enum State { Patrol, Alert, Chase, Attack, Hurt, Dead }

        [Header("引用")]
        [SerializeField] Animator animator;
        [SerializeField] NavMeshAgent agent;
        [SerializeField] Health health;
        [SerializeField] Transform player;

        [Header("巡逻")]
        [SerializeField] float patrolRadius = 8f;
        [SerializeField] float patrolWaitMin = 1f;
        [SerializeField] float patrolWaitMax = 3f;
        Vector3 _startPos;
        Vector3 _patrolTarget;
        float _waitTimer;

        [Header("感知")]
        [SerializeField] float sightRange = 12f;
        [SerializeField] float sightAngle = 90f;
        [SerializeField] float attackRange = 2f;
        [SerializeField] LayerMask sightBlock;

        [Header("战斗")]
        [SerializeField] int attackDamage = 8;
        [SerializeField] float attackCooldown = 1.5f;
        [SerializeField] float attackWindup = 0.4f;
        float _nextAttackTime;

        [Header("调色")]
        [SerializeField] Renderer[] tintRenderers;
        [SerializeField] Color yanyunTint = new(0.65f, 0.70f, 0.72f, 1f); // 青墨调

        State _state = State.Patrol;
        float _stateTimer;
        bool _dead;

        void Awake()
        {
            if (animator == null) animator = GetComponent<Animator>();
            if (agent == null) agent = GetComponent<NavMeshAgent>();
            if (health == null) health = GetComponent<Health>();
            _startPos = transform.position;
            _patrolTarget = _startPos;
        }

        void Start()
        {
            // 应用燕云青墨调色
            ApplyYanYunTint();
            // 找主角(用 tag 或 PlayerController 类型查找)
            var pc = FindFirstObjectByType<PlayerController>();
            if (pc != null) player = pc.transform;
        }

        void Update()
        {
            _stateTimer += Time.deltaTime;
            switch (_state)
            {
                case State.Patrol: UpdatePatrol(); break;
                case State.Alert: UpdateAlert(); break;
                case State.Chase: UpdateChase(); break;
                case State.Attack: UpdateAttack(); break;
                case State.Hurt: UpdateHurt(); break;
                case State.Dead: break;
            }
            UpdateAnimator();
        }

        void UpdatePatrol()
        {
            // 到达巡逻点
            if (!agent.pathPending && agent.remainingDistance < 0.5f)
            {
                _waitTimer -= Time.deltaTime;
                if (_waitTimer <= 0)
                {
                    PickPatrolTarget();
                    agent.SetDestination(_patrolTarget);
                    _waitTimer = Random.Range(patrolWaitMin, patrolWaitMax);
                }
            }
            // 检测玩家
            if (player != null && CanSeePlayer())
            {
                ChangeState(State.Alert);
            }
        }

        void UpdateAlert()
        {
            // 警戒 0.5 秒后追击
            agent.isStopped = true;
            if (_stateTimer > 0.5f)
            {
                agent.isStopped = false;
                ChangeState(State.Chase);
            }
        }

        void UpdateChase()
        {
            if (player == null) { ChangeState(State.Patrol); return; }
            agent.SetDestination(player.position);

            float dist = Vector3.Distance(transform.position, player.position);
            if (dist <= attackRange && Time.time > _nextAttackTime)
            {
                ChangeState(State.Attack);
                _nextAttackTime = Time.time + attackCooldown;
                StartCoroutine(PerformAttack());
            }
            else if (dist > sightRange * 1.5f)
            {
                ChangeState(State.Patrol);
            }
        }

        void UpdateAttack()
        {
            agent.isStopped = true;
            // 朝向玩家
            if (player != null)
            {
                var dir = (player.position - transform.position);
                dir.y = 0;
                if (dir.sqrMagnitude > 0.01f)
                {
                    var rot = Quaternion.LookRotation(dir);
                    transform.rotation = Quaternion.Slerp(transform.rotation, rot, 8f * Time.deltaTime);
                }
            }
            // Attack 状态在 PerformAttack 协程结束后切回 Chase
            if (_stateTimer > 1.2f)
                ChangeState(State.Chase);
        }

        void UpdateHurt()
        {
            agent.isStopped = true;
            if (_stateTimer > 0.4f)
            {
                agent.isStopped = false;
                ChangeState(State.Chase);
            }
        }

        IEnumerator PerformAttack()
        {
            // 蓄力
            yield return new WaitForSeconds(attackWindup);
            // 命中判定
            if (player != null)
            {
                float dist = Vector3.Distance(transform.position, player.position);
                if (dist <= attackRange + 0.3f)
                {
                    var angle = Vector3.Angle(transform.forward, (player.position - transform.position).normalized);
                    if (angle < 60f)
                    {
                        if (player.TryGetComponent<IDamageable>(out var dmg))
                            dmg.TakeDamage(attackDamage, transform.position);
                    }
                }
            }
        }

        bool CanSeePlayer()
        {
            if (player == null) return false;
            var toPlayer = player.position - transform.position;
            if (toPlayer.magnitude > sightRange) return false;
            if (Vector3.Angle(transform.forward, toPlayer.normalized) > sightAngle * 0.5f) return false;
            // 视线遮挡
            if (Physics.Raycast(transform.position + Vector3.up * 1.5f, toPlayer.normalized, toPlayer.magnitude, sightBlock))
                return false;
            return true;
        }

        void PickPatrolTarget()
        {
            Vector2 r = Random.insideUnitCircle * patrolRadius;
            _patrolTarget = _startPos + new Vector3(r.x, 0, r.y);
        }

        void ChangeState(State s)
        {
            if (_state == s) return;
            _state = s;
            _stateTimer = 0;
        }

        void UpdateAnimator()
        {
            if (animator == null) return;
            animator.SetBool("Patrol", _state == State.Patrol || _state == State.Alert);
            animator.SetBool("Chase", _state == State.Chase);
            animator.SetBool("Attack", _state == State.Attack);
            animator.SetBool("Hurt", _state == State.Hurt);
            animator.SetBool("Dead", _state == State.Dead);
            animator.SetFloat("MoveSpeed", agent.velocity.magnitude);
        }

        // 燕云青墨调色(运行时改 tint,不改贴图)
        void ApplyYanYunTint()
        {
            if (tintRenderers == null) return;
            foreach (var r in tintRenderers)
            {
                if (r == null) continue;
                foreach (var mat in r.materials)
                {
                    if (mat.HasProperty("_BaseColor"))
                        mat.SetColor("_BaseColor", yanyunTint);
                    else if (mat.HasProperty("_Color"))
                        mat.SetColor("_Color", yanyunTint);
                }
            }
        }

        // IDamageable
        public void TakeDamage(int dmg, Vector3 fromPos)
        {
            if (_dead) return;
            if (health != null) health.ApplyDamage(dmg);
            if (health != null && health.IsDead)
            {
                _dead = true;
                ChangeState(State.Dead);
                agent.isStopped = true;
                // 禁用碰撞和脚本,让尸体留下
                if (TryGetComponent<Collider>(out var c)) c.enabled = false;
                this.enabled = false;
            }
            else
            {
                ChangeState(State.Hurt);
                // 击退
                var dir = (transform.position - fromPos).normalized;
                StartCoroutine(Knockback(dir));
            }
        }

        IEnumerator Knockback(Vector3 dir)
        {
            float t = 0;
            Vector3 start = transform.position;
            Vector3 end = start + dir * 0.6f;
            while (t < 0.15f)
            {
                t += Time.deltaTime;
                if (agent != null) agent.Warp(Vector3.Lerp(start, end, t / 0.15f));
                yield return null;
            }
        }
    }
}
