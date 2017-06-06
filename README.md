Build:

```
./build.sh build
```

Publish:

```
./build.sh publish
```

Deploy:


```
helm upgrade -i gluster ./app-gluster
```

After all gluster pods (3 by default) are up and running, connect them into a cluster:

```
kubectl exec gluster-app-gluster-0 -- gluster peer probe gluster-app-gluster-1.gluster-app-gluster.default.svc.cluster.local
kubectl exec gluster-app-gluster-0 -- gluster peer probe gluster-app-gluster-2.gluster-app-gluster.default.svc.cluster.local
kubectl exec gluster-app-gluster-1 -- gluster peer probe gluster-app-gluster-0.gluster-app-gluster.default.svc.cluster.local
```

Unfortunately there is an issue with reverse DNS lookup for StatefulSet pods in Kubernetes 1.5.
It looks like this issue is fixed in Kubernetes 1.6, but verify it before going further. 

If the issue is present, gluster peer hostnames must be fixed in some peers at least.
Fortunately this is a one-time procedure:

```
kubectl exec gluster-app-gluster-0 -- /bin/bash -c 'sed -r -n -i -e '\''/^\s*hostname[0-9]+\s*=.*/ !p'\'' -e '\''/^\s*hostname[0-9]+\s*=gluster-app-gluster-[0-9]+\.gluster-app-gluster\.default\.svc\.cluster\.local$/ p'\'' /var/lib/glusterd/peers/*; systemctl restart glusterd'
kubectl exec gluster-app-gluster-1 -- /bin/bash -c 'sed -r -n -i -e '\''/^\s*hostname[0-9]+\s*=.*/ !p'\'' -e '\''/^\s*hostname[0-9]+\s*=gluster-app-gluster-[0-9]+\.gluster-app-gluster\.default\.svc\.cluster\.local$/ p'\'' /var/lib/glusterd/peers/*; systemctl restart glusterd'
kubectl exec gluster-app-gluster-2 -- /bin/bash -c 'sed -r -n -i -e '\''/^\s*hostname[0-9]+\s*=.*/ !p'\'' -e '\''/^\s*hostname[0-9]+\s*=gluster-app-gluster-[0-9]+\.gluster-app-gluster\.default\.svc\.cluster\.local$/ p'\'' /var/lib/glusterd/peers/*; systemctl restart glusterd'
```

Now you can verify that all peer addresses are correct:

```
kubectl exec gluster-app-gluster-0 -- gluster pool list
kubectl exec gluster-app-gluster-1 -- gluster pool list
kubectl exec gluster-app-gluster-2 -- gluster pool list
```

Create a gluster volume:

```
kubectl exec gluster-app-gluster-0 -- mkdir -p /bricks/vol1
kubectl exec gluster-app-gluster-1 -- mkdir -p /bricks/vol1
kubectl exec gluster-app-gluster-2 -- mkdir -p /bricks/vol1
kubectl exec gluster-app-gluster-0 -- gluster volume create vol1 replica 3 arbiter 1 gluster-app-gluster-0.gluster-app-gluster.default.svc.cluster.local:/bricks/vol1 gluster-app-gluster-1.gluster-app-gluster.default.svc.cluster.local:/bricks/vol1 gluster-app-gluster-2.gluster-app-gluster.default.svc.cluster.local:/bricks/vol1
kubectl exec gluster-app-gluster-0 -- gluster volume start vol1
kubectl exec gluster-app-gluster-0 -- gluster volume bitrot vol1 enable
```

... and check its status:
```
kubectl exec gluster-app-gluster-0 -- gluster volume info
kubectl exec gluster-app-gluster-0 -- gluster volume status
```

Now we can create corresponding Gluster Kubernetes persistent volume, ...

```
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: vol1
spec:
  capacity:
    storage: 10Gi
  accessModes:
  - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  glusterfs:
    endpoints: gluster-app-gluster
    path: vol1
EOF
```

... persistent volume claim, ...

```
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: vol1
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  volumeName: vol1
EOF
```

... and at last, use this claim in a pod:

```
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: gluster-test-pod
spec:
  terminationGracePeriodSeconds: 3
  containers:
  - name: main
    image: busybox
    command: ["/bin/sh", "-c", "while true; do sleep 30; date > /vol1/date.txt; cat /vol1/date.txt; ls -la /vol1; done"]
    volumeMounts:
    - name: vol1
      mountPath: /vol1
  volumes:
  - name: vol1
    persistentVolumeClaim:
      claimName: vol1
EOF
```
