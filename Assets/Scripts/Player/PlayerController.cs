// 定风波 主角控制器(Unity 6 LTS)
// 基于 CharacterController + 状态机 + Animator 驱动
// 走/跑/跳/击/避 五大状态,接入虚拟摇杆 + 按钮(HUD 脚本提供输入)
using System;
using UnityEngine;

namespace Dingfengbo.Player
{
    [RequireComponent(typeof(CharacterController))]
    public class PlayerController : MonoBehaviour
    {
        // ============ 公开配置 ============
        [Header("移动")]
        [SerializeField] float walkSpeed = 3.5f;
        [SerializeField] float runSpeed = 6.5f;
        [SerializeField] float acceleration = 12f;
        [SerializeField] float rotationSpeed = 12f;

        [Header("跳跃")]
        [SerializeField] float jumpHeight = 2.2f;
        [SerializeField] float gravity = -25f;

        [Header("闪避")]
        [SerializeField] float dodgeDistance = 4.5f;
        [SerializeField] float dodgeDuration = 0.32f;
        [SerializeField] float dodgeInvincibleStart = 0.05f; // 无敌帧起始
        [SerializeField] float dodgeInvincibleEnd = 0.22f;   // 无敌帧结束

        [Header("战斗")]
        [SerializeField] float attackRange = 2.2f;
        [SerializeField] float attackArc = 90f;
        [SerializeField] int attackDamage = 12;
        [SerializeField] LayerMask enemyLayer;

        [Header("引用")]
        [SerializeField] Animator animator;
        [SerializeField] Camera mainCamera;
        CharacterController _cc;

        // ============ 状态机 ============
        public enum State { Idle, Walk, Run, Jump, Attack, Dodge, Hit, Dead }
        public State CurrentState { get; private set; } = State.Idle;

        // ============ 输入(由 HUD 注入) ============
        public Vector2 MoveInput { get; set; }     // 摇杆方向,-1~1
        public bool RunHeld { get; set; }          // 是否在跑(摇杆推满)
        public bool JumpPressed { get; set; }      // 跳跃按下(本帧)
        public bool AttackPressed { get; set; }    // 攻击按下
        public bool DodgePressed { get; set; }     // 闪避按下

        // ============ 内部 ============
        Vector3 _velocity;
        float _stateTimer;
        int _attackCombo; // 0-2 三连击
        float _lastAttackTime;
        const float ComboResetTime = 0.6f;

        // 无敌帧(给 EnemyAI 检查用)
        public bool IsInvincible => CurrentState == State.Dodge &&
            _stateTimer >= dodgeInvincibleStart && _stateTimer <= dodgeInvincibleEnd;

        void Awake()
        {
            _cc = GetComponent<CharacterController>();
            if (animator == null) animator = GetComponent<Animator>();
            if (mainCamera == null) mainCamera = Camera.main;
        }

        void Update()
        {
            _stateTimer += Time.deltaTime;
            UpdateState();
            ApplyGravity();
            ResetFrameInputs();
        }

        void UpdateState()
        {
            switch (CurrentState)
            {
                case State.Idle:
                case State.Walk:
                case State.Run:
                    HandleGrounded();
                    break;
                case State.Jump:
                    HandleAirborne();
                    break;
                case State.Attack:
                    HandleAttack();
                    break;
                case State.Dodge:
                    HandleDodge();
                    break;
                case State.Hit:
                    if (_stateTimer > 0.4f) ChangeState(State.Idle);
                    break;
                case State.Dead:
                    // 等待复活或场景重置
                    break;
            }
        }

        void HandleGrounded()
        {
            // 跳转优先
            if (JumpPressed && _cc.isGrounded)
            {
                _velocity.y = Mathf.Sqrt(jumpHeight * -2f * gravity);
                ChangeState(State.Jump);
                return;
            }
            // 闪避
            if (DodgePressed)
            {
                ChangeState(State.Dodge);
                _velocity = transform.forward * (dodgeDistance / dodgeDuration);
                return;
            }
            // 攻击(优先于移动)
            if (AttackPressed)
            {
                ChangeState(State.Attack);
                _velocity = Vector3.zero;
                return;
            }

            // 移动
            if (MoveInput.sqrMagnitude > 0.01f)
            {
                // 相机方向投影
                var cam = mainCamera != null ? mainCamera.transform : transform;
                var fwd = Vector3.ProjectOnPlane(cam.forward, Vector3.up).normalized;
                var right = Vector3.ProjectOnPlane(cam.right, Vector3.up).normalized;
                var dir = (right * MoveInput.x + fwd * MoveInput.y).normalized;

                // 转向
                var targetRot = Quaternion.LookRotation(dir);
                transform.rotation = Quaternion.Slerp(transform.rotation, targetRot, rotationSpeed * Time.deltaTime);

                // 速度
                float targetSpeed = RunHeld ? runSpeed : walkSpeed;
                var desiredVel = dir * targetSpeed;
                _velocity.x = Mathf.Lerp(_velocity.x, desiredVel.x, acceleration * Time.deltaTime);
                _velocity.z = Mathf.Lerp(_velocity.z, desiredVel.z, acceleration * Time.deltaTime);

                ChangeState(RunHeld ? State.Run : State.Walk);
            }
            else
            {
                _velocity.x = Mathf.Lerp(_velocity.x, 0, acceleration * Time.deltaTime);
                _velocity.z = Mathf.Lerp(_velocity.z, 0, acceleration * Time.deltaTime);
                ChangeState(State.Idle);
            }
        }

        void HandleAirborne()
        {
            // 空中可微调方向
            if (MoveInput.sqrMagnitude > 0.01f)
            {
                var cam = mainCamera != null ? mainCamera.transform : transform;
                var fwd = Vector3.ProjectOnPlane(cam.forward, Vector3.up).normalized;
                var right = Vector3.ProjectOnPlane(cam.right, Vector3.up).normalized;
                var dir = (right * MoveInput.x + fwd * MoveInput.y).normalized;
                var targetRot = Quaternion.LookRotation(dir);
                transform.rotation = Quaternion.Slerp(transform.rotation, targetRot, rotationSpeed * Time.deltaTime);
                var desiredVel = dir * walkSpeed * 0.6f;
                _velocity.x = Mathf.Lerp(_velocity.x, desiredVel.x, 6f * Time.deltaTime);
                _velocity.z = Mathf.Lerp(_velocity.z, desiredVel.z, 6f * Time.deltaTime);
            }
            if (_cc.isGrounded && _velocity.y < 0)
            {
                ChangeState(State.Idle);
            }
        }

        void HandleAttack()
        {
            // Combo 系统:三连击 0→1→2→0
            if (_stateTimer < 0.35f) // 当前段未完成
                return;

            if (Time.time - _lastAttackTime > ComboResetTime)
                _attackCombo = 0;

            if (AttackPressed && _attackCombo < 2)
            {
                _attackCombo++;
                _lastAttackTime = Time.time;
                ChangeState(State.Attack);
                ApplyAttackDamage();
                return;
            }

            // 三连击完成或超时
            if (_stateTimer > 0.55f)
            {
                _attackCombo = 0;
                ChangeState(State.Idle);
            }
        }

        void ApplyAttackDamage()
        {
            // 扇形范围伤害检测
            var hits = Physics.OverlapSphere(transform.position + Vector3.up * 1f, attackRange, enemyLayer);
            foreach (var hit in hits)
            {
                var dirToHit = (hit.transform.position - transform.position).normalized;
                if (Vector3.Angle(transform.forward, dirToHit) < attackArc * 0.5f)
                {
                    var dmg = hit.GetComponentInParent<IDamageable>();
                    dmg?.TakeDamage(attackDamage + _attackCombo * 4, transform.position);
                }
            }
        }

        void HandleDodge()
        {
            if (_stateTimer >= dodgeDuration)
            {
                _velocity = Vector3.zero;
                ChangeState(State.Idle);
            }
        }

        void ApplyGravity()
        {
            if (_cc.isGrounded && _velocity.y < 0)
                _velocity.y = -2f;
            _velocity.y += gravity * Time.deltaTime;
            _cc.Move(_velocity * Time.deltaTime);
        }

        void ChangeState(State newState)
        {
            if (CurrentState == newState) return;
            CurrentState = newState;
            _stateTimer = 0f;
            UpdateAnimator();
        }

        void UpdateAnimator()
        {
            if (animator == null) return;
            animator.SetBool("Idle", CurrentState == State.Idle);
            animator.SetBool("Walk", CurrentState == State.Walk);
            animator.SetBool("Run", CurrentState == State.Run);
            animator.SetBool("Airborne", CurrentState == State.Jump);
            animator.SetInteger("AttackCombo", CurrentState == State.Attack ? _attackCombo : -1);
            animator.SetBool("Dodge", CurrentState == State.Dodge);
            animator.SetBool("Hit", CurrentState == State.Hit);
            animator.SetBool("Dead", CurrentState == State.Dead);
        }

        void ResetFrameInputs()
        {
            // 按键型输入只在一帧有效
            JumpPressed = false;
            AttackPressed = false;
            DodgePressed = false;
        }

        // ============ 受伤/死亡接口 ============
        public void TakeDamage(int dmg, Vector3 fromPos)
        {
            if (IsInvincible || CurrentState == State.Dead) return;
            ChangeState(State.Hit);
            var dir = (transform.position - fromPos).normalized;
            _velocity = dir * 4f + Vector3.up * 3f; // 击退
            // 实际血量扣减在 Health.cs 处理
            if (TryGetComponent<Health>(out var h))
                h.ApplyDamage(dmg);
        }

        public void Die()
        {
            ChangeState(State.Dead);
        }

        // 调试可视化
        void OnDrawGizmosSelected()
        {
            Gizmos.color = Color.red;
            Gizmos.DrawWireSphere(transform.position + Vector3.up * 1f, attackRange);
            // 扇形
            var fwd = transform.forward;
            var left = Quaternion.Euler(0, -attackArc * 0.5f, 0) * fwd;
            var right = Quaternion.Euler(0, attackArc * 0.5f, 0) * fwd;
            Gizmos.DrawLine(transform.position, transform.position + left * attackRange);
            Gizmos.DrawLine(transform.position, transform.position + right * attackRange);
        }
    }

    public interface IDamageable
    {
        void TakeDamage(int dmg, Vector3 fromPos);
    }
}
