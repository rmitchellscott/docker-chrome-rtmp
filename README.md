# PageCaster
Pagecaster streams a web browser to an RTMP server, with audio! It does this by creating a virtual display, opening chrome in kiosk mode on that display, and then streaming the framebuffer via ffmpeg to an RTMP server. A 480p stream on my system consumes about 1.2 cores of CPU and 350MB of RAM. I haven't tried to do anything with Intel QuickSync, maybe someday!

# Examples
The following examples are provided as a way to get started. Some adjustments may be required before production use, particularly regarding secret management.
## Docker
```shell
docker run -d \
--shm-size=256m \
-e WEB_URL="https://weatherstar.netbymatt.com/" \
-e RTMP_URL="rtmp://supercool.stream:1935/live" \
-e SCREEN_HEIGHT=480 \
-e SCREEN_WIDTH=854 \
ghcr.io/rmitchellscott/pagecaster
```

## Docker Compse

```yaml
version: '3.8'

services:
  pagecaster:
    image: ghcr.io/rmitchellscott/pagecaster
    deploy:
      resources:
        limits:
          shm_size: 256m
    environment:
      - WEB_URL=https://weatherstar.netbymatt.com/
      - RTMP_URL=rtmp://supercool.stream:1935/live
      - SCREEN_HEIGHT=480
      - SCREEN_WIDTH=854
    restart: always

```

## Kubernetes statefulset
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: pagecaster
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/component: pagecaster
      app.kubernetes.io/instance: pagecaster
      app.kubernetes.io/name: pagecaster
  serviceName: pagecaster
  template:
    metadata:
      labels:
        app.kubernetes.io/component: pagecaster
        app.kubernetes.io/instance: pagecaster
        app.kubernetes.io/name: pagecaster
    spec:
      containers:
      - env:
        - name: RTMP_URL
          value: rtmp://supercool.stream:1935/live
        - name: SCREEN_HEIGHT
          value: "480"
        - name: SCREEN_WIDTH
          value: "854"
        - name: WEB_URL
          value: https://weatherstar.netbymatt.com/
        image: ghcr.io/rmitchellscott/pagecaster
        imagePullPolicy: IfNotPresent
        name: pagecaster
        volumeMounts:
        - mountPath: /dev/shm
          name: dshm
      volumes:
      - emptyDir:
          sizeLimit: 256Mi
        name: dshm
```

## Kubernetes via flux, using the bjw-s/app-template Helm chart
```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: pagecaster
spec:
  chart:
    spec:
      chart: app-template
      version: 3.3.2
      reconcileStrategy: ChartVersion
      sourceRef:
        kind: HelmRepository
        namespace: flux-system
        name: bjw-s
  interval: 1h
  driftDetection:
    mode: enabled
  values:
    controllers:
     pagecaster:
        type: statefulset
        replicas: 1
        containers:
          pagecaster:
            image:
              repository: ghcr.io/rmitchellscott/pagecaster
              pullPolicy: IfNotPresent
            env:
              WEB_URL: "https://weatherstar.netbymatt.com/"
              RTMP_URL: rtmp://supercool.stream:1935/live
              SCREEN_WIDTH: 854
              SCREEN_HEIGHT: 480

    persistence:
      dshm:
        enabled: true
        type: emptyDir
        sizeLimit: 256Mi
        globalMounts:
          - path: /dev/shm
            readOnly: false
````

# Environment Variables

| Variable                 | Required? | Details | Example |
|--------------------------|-----------|---------|---------|
| WEB_URL               | yes       | URL to stream | https://weatherstar.netbymatt.com/   |
| RTMP_URL               | yes       | RMTP URL to stream to | rtmp://supercool.stream:1935/live |
| SCREEN_HEIGHT           | yes       | Height of browser window | 480 |
| SCREEN_WIDTH                  | yes       | Width of browser window | 854
