using UnityEngine;

namespace Harness
{
    public static class DemoWorld
    {
        // Built-in primitives only. No external assets or render pipeline required.
        public static GameObject Create()
        {
            var root = new GameObject("HarnessDemo");
            var floor = GameObject.CreatePrimitive(PrimitiveType.Cube);
            floor.name = "Floor";
            floor.transform.SetParent(root.transform);
            floor.transform.position = new Vector3(0, -0.5f, 0);
            floor.transform.localScale = new Vector3(12, 1, 12);
            var ball = GameObject.CreatePrimitive(PrimitiveType.Sphere);
            ball.name = "PhysicsBall";
            ball.transform.SetParent(root.transform);
            ball.transform.position = new Vector3(0, 3, 0);
            ball.AddComponent<Rigidbody>();
            var cameraObject = new GameObject("Main Camera", typeof(Camera));
            cameraObject.tag = "MainCamera";
            cameraObject.transform.SetParent(root.transform);
            cameraObject.transform.position = new Vector3(7, 6, -9);
            cameraObject.transform.LookAt(new Vector3(0, 1, 0));
            var lightObject = new GameObject("Directional Light", typeof(Light));
            lightObject.transform.SetParent(root.transform);
            lightObject.GetComponent<Light>().type = LightType.Directional;
            lightObject.transform.rotation = Quaternion.Euler(45, -30, 0);
            return root;
        }
    }
}
