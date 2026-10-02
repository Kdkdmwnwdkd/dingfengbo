// 血量组件(主角和敌人共用)
using UnityEngine;
using UnityEngine.Events;

namespace Dingfengbo.Player
{
    public class Health : MonoBehaviour
    {
        [SerializeField] int maxHealth = 100;
        public int Current { get; private set; }
        public float Percent => (float)Current / maxHealth;
        public bool IsDead => Current <= 0;

        public UnityEvent<int, int> OnDamage; // 当前值, 减少值
        public UnityEvent OnDeath;

        void Awake()
        {
            Current = maxHealth;
        }

        public void ApplyDamage(int dmg)
        {
            if (IsDead) return;
            Current = Mathf.Max(0, Current - dmg);
            OnDamage?.Invoke(Current, dmg);
            if (IsDead)
            {
                OnDeath?.Invoke();
                if (TryGetComponent<PlayerController>(out var p)) p.Die();
            }
        }

        public void Heal(int amount)
        {
            Current = Mathf.Min(maxHealth, Current + amount);
        }
    }
}
