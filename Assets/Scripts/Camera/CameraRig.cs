// 第三人称相机(Unity 6 LTS)
// 燕云风格:近身跟踪 + 仰视微距 + 远景虚化
using UnityEngine;

namespace Dingfengbo.Camera
{
    public class CameraRig : MonoBehaviour
    {
        [SerializeField] Transform target;
        [SerializeField] Vector3 offset = new(0, 3.2f, -5.5f);
        [SerializeField] float followSpeed = 8f;
        [SerializeField] float rotationLerp = 6f;
        [SerializeField] float lookAtHeight = 1.6f;
        [SerializeField] float cameraShake = 0.05f;
        [SerializeField] UnityEngine.Camera cam;

        Vector3 _shakeVel;

        public Transform Target => target;
        public void SetShake(float magnitude) { _shakeVel = Random.insideUnitSphere * magnitude; }

        void LateUpdate()
        {
            if (target == null) return;

            // 期望位置(目标位置 + offset,offset 跟着目标的 yaw 旋转)
            float yaw = target.eulerAngles.y;
            var rot = Quaternion.Euler(0, yaw, 0);
            var desiredPos = target.position + rot * offset;

            // 平滑跟随
            transform.position = Vector3.Lerp(transform.position, desiredPos + _shakeVel, followSpeed * Time.deltaTime);
            _shakeVel = Vector3.Lerp(_shakeVel, Vector3.zero, 5f * Time.deltaTime);

            // 看向角色胸口高度
            var lookTarget = target.position + Vector3.up * lookAtHeight;
            var lookRot = Quaternion.LookRotation(lookTarget - transform.position, Vector3.up);
            transform.rotation = Quaternion.Slerp(transform.rotation, lookRot, rotationLerp * Time.deltaTime);

            // 锁定横屏比例补偿(防止 letterbox 时镜头偏移)
            if (cam != null)
            {
                cam.fieldOfView = Mathf.Clamp(cam.fieldOfView + Input.GetAxis("Mouse ScrollWheel") * 4f, 40f, 70f);
            }
        }
    }
}
