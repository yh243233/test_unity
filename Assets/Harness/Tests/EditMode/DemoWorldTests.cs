using NUnit.Framework;
using UnityEngine;

namespace Harness.Tests
{
    public class DemoWorldTests
    {
        [Test]
        public void DemoProvidesCameraAndPhysicsGeometry()
        {
            var root = DemoWorld.Create();
            try
            {
                Assert.That(root.GetComponentsInChildren<Camera>().Length, Is.EqualTo(1));
                var floor = root.transform.Find("Floor");
                Assert.That(floor.GetComponent<BoxCollider>(), Is.Not.Null);
                Assert.That(floor.position.y + floor.localScale.y / 2, Is.EqualTo(0).Within(0.001f));
                var ball = root.transform.Find("PhysicsBall");
                Assert.That(ball.GetComponent<SphereCollider>(), Is.Not.Null);
                Assert.That(ball.GetComponent<Rigidbody>().useGravity, Is.True);
            }
            finally { Object.DestroyImmediate(root); }
        }
    }
}
