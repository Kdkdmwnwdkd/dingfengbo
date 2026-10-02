// 虚拟摇杆 + 攻击/闪避/跳跃按钮(Unity 6 LTS)
// 横屏布局:摇杆左下、按钮右下,使用 Canvas 锚点自适应分辨率
// 摇杆可点击屏幕任意空白区域召唤(动态摇杆,燕云风格)
using UnityEngine;
using UnityEngine.UI;
using UnityEngine.EventSystems;
using Dingfengbo.Player;

namespace Dingfengbo.UI
{
    public class VirtualHUD : MonoBehaviour
    {
        [Header("引用")]
        [SerializeField] PlayerController player;
        [SerializeField] RectTransform joystickBase;  // 摇杆底盘
        [SerializeField] RectTransform joystickKnob;   // 摇杆头
        [SerializeField] float joystickRadius = 90f;
        [SerializeField] RectTransform attackBtn;       // 攻击按钮(右下)
        [SerializeField] RectTransform dodgeBtn;       // 闪避按钮
        [SerializeField] RectTransform jumpBtn;         // 跳跃按钮

        [Header("血量 UI")]
        [SerializeField] Image healthFill;
        [SerializeField] RectTransform healthRoot;

        // 内部状态
        int _joystickPointerId = -1;
        bool _joystickActive;
        Vector2 _joystickOrigin;
        Vector2 _moveVec;

        // 按钮按下
        bool _attackHeld;
        bool _dodgeHeld;
        bool _jumpHeld;

        void Start()
        {
            // 默认隐藏动态摇杆(等用户首次触摸)
            if (joystickBase != null) joystickBase.gameObject.SetActive(false);
        }

        void Update()
        {
            if (player == null) return;
            // 注入输入
            player.MoveInput = _moveVec;
            player.RunHeld = _moveVec.sqrMagnitude > 0.85f;
            player.AttackPressed = _attackHeld && ButtonPressedThisFrame(ref _attackHeld);
            player.DodgePressed = _dodgeHeld && ButtonPressedThisFrame(ref _dodgeHeld);
            player.JumpPressed = _jumpHeld && ButtonPressedThisFrame(ref _jumpHeld);
        }

        // 简化:按钮在 OnPointerDown/Up 设置 _held,这里在 Update 一次性消费
        bool ButtonPressedThisFrame(ref bool held)
        {
            // 仅在按下瞬间触发,Update 末尾 ResetFrameInputs 会清掉 Pressed
            // 这里给个真值让 PlayerController 读到(下一帧会被它自己清掉)
            held = false;
            return true;
        }

        // ============ 摇杆:动态召唤 + 拖拽 ============
        public void OnScreenPointerDown(BaseEventData data)
        {
            if (_joystickActive) return;
            var pe = (PointerEventData)data;
            // 排除点在按钮上(按钮自己处理)
            if (IsOverButton(pe.position)) return;

            _joystickActive = true;
            _joystickPointerId = pe.pointerId;
            _joystickOrigin = pe.position;
            if (joystickBase != null)
            {
                joystickBase.gameObject.SetActive(true);
                joystickBase.position = _joystickOrigin;
            }
            if (joystickKnob != null) joystickKnob.position = _joystickOrigin;
        }

        public void OnScreenDrag(BaseEventData data)
        {
            if (!_joystickActive) return;
            var pe = (PointerEventData)data;
            if (pe.pointerId != _joystickPointerId) return;

            Vector2 delta = pe.position - _joystickOrigin;
            if (delta.magnitude > joystickRadius)
                delta = delta.normalized * joystickRadius;

            if (joystickKnob != null)
                joystickKnob.position = _joystickOrigin + delta;

            // 归一化到 -1~1
            _moveVec = delta / joystickRadius;
        }

        public void OnScreenPointerUp(BaseEventData data)
        {
            var pe = (PointerEventData)data;
            if (pe.pointerId != _joystickPointerId) return;
            _joystickActive = false;
            _joystickPointerId = -1;
            _moveVec = Vector2.zero;
            if (joystickBase != null) joystickBase.gameObject.SetActive(false);
        }

        bool IsOverButton(Vector2 screenPos)
        {
            // 简单 hit test:检查屏幕坐标是否落在任一按钮 Rect 内
            return InsideRect(attackBtn, screenPos)
                || InsideRect(dodgeBtn, screenPos)
                || InsideRect(jumpBtn, screenPos);
        }

        static bool InsideRect(RectTransform rt, Vector2 screenPos)
        {
            if (rt == null) return false;
            return RectTransformUtility.RectangleContainsScreenPoint(rt, screenPos);
        }

        // ============ 按钮事件(由 UGUI Button 的 OnPointerDown 调用) ============
        public void OnAttackDown() { _attackHeld = true; }
        public void OnDodgeDown()  { _dodgeHeld = true; }
        public void OnJumpDown()   { _jumpHeld = true; }
        public void OnAttackUp()    { _attackHeld = false; }
        public void OnDodgeUp()    { _dodgeHeld = false; }
        public void OnJumpUp()      { _jumpHeld = false; }

        // ============ 血量 UI ============
        public void SetHealth(float percent)
        {
            if (healthFill != null)
                healthFill.fillAmount = Mathf.Clamp01(percent);
        }

        // ============ 布局自检 ============
        public void LayoutForLandscape()
        {
            // 横屏默认布局:摇杆左下,按钮右下
            // 实际锚点在 Prefab 里设置,这里只兜底确保
            if (joystickBase != null)
            {
                var anchorMin = new Vector2(0.18f, 0.18f);
                joystickBase.anchorMin = anchorMin;
                joystickBase.anchorMax = anchorMin;
            }
            if (attackBtn != null)
            {
                attackBtn.anchorMin = new Vector2(0.85f, 0.18f);
                attackBtn.anchorMax = new Vector2(0.85f, 0.18f);
            }
            if (dodgeBtn != null)
            {
                dodgeBtn.anchorMin = new Vector2(0.75f, 0.30f);
                dodgeBtn.anchorMax = new Vector2(0.75f, 0.30f);
            }
            if (jumpBtn != null)
            {
                jumpBtn.anchorMin = new Vector2(0.92f, 0.32f);
                jumpBtn.anchorMax = new Vector2(0.92f, 0.32f);
            }
        }
    }
}
