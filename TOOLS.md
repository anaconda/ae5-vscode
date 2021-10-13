# Creating the tools volume

Starting with version 5.5.1, Anaconda Enterprise has the ability
to take advantage of customized versions of in-browser IDEs such as
VSCode, RStudio, Zeppelin, and Jupyter. These tools are expected
to live in a special volume mounted at the `/tools` mount point,
provisioned as a standard AE5
[external file share](https://enterprise-docs.anaconda.com/en/latest/admin/advanced/nfs.html).

This document provides instructions for setting up this volume.
Because all of the tools live in this volume, these instructions
only need to be followed once.

While any file share that meets the criteria listed in the next
section will be acceptable, we offer two recommendations below
to re-use existing volumes effectively.

# General requirements

* We recommend that the volume have at least 10GB of space.
  The precise needs will depend on the number of tools and
  extensions installed.
* It must be accessible to all AE5 nodes.
* It must be group writable by a fixed group ID (GID). Any value of
  the GID, including 0, is acceptable.
* For Gravity-based clusters, it must be an NFS volume.
* For BYOK8s clusters, you can use NFS or any `PersistentVolume`
  with `ReadWriteOnce` or `ReadWriteMany` semantics.
* Because the volume will be written to only during installation
  or maintenance, it is reasonable to favor read performance over
  write if such a choice is available.

Once the volume is created, following the instructions provided
in our [documentation](https://enterprise-docs.anaconda.com/en/latest/admin/advanced/nfs.html)
to add this volume to AE5. Some key aspects that must be correct:

- The mount point must be `/tools`.
- For a basic `nfs:` mount, make sure the `groupID:` value is
  set to the known group ID that has write access to the volume.
- For a `pvc:` mount, the `groupID:` can either be included in
  this section or in the `PersistentVolume` specification itself,
  using a `pv.beta.kubernetes.io/gid` annotation (more information
  [here](https://kubernetes.io/docs/tasks/configure-pod-container/configure-persistent-volume-storage/#access-control)).
- During normal operation, we will set `readOnly: true` to ensure
  that users cannot accidentally modify installed tools. But during
  the installation process, we will set `readOnly: false`.
- Interrupting or removing access to the the volume from the cluster
  is extremely disruptive. In particular, all sessions, deployments,
  and jobs will have to be stopped and re-created. For this reason,
  we strongly recommend selecting a volume that will remain
  available for the life of the cluster.
   
# Recommendation: managed persistence

If you are using the new Managed Persistence feature of Anaconda
Enterprise 5, we strongly recommend re-using the MP volume to
host the tools directory as well. To do so, simply create a new
directory `tools` alongside the existing directories: `projects`,
`environments`, and `gallery`. Give it the same ownership and
permissions given these other directories.

For instance, suppose your persistence specification
```
persistence:
   projects:
     pvc: anaconda-persistence
     subPath: projects
```
Then the specification for the tool volume in the `volumes:` section
will look something like this:
```
volumes:
   /tools:
     pvc: anaconda-persistence
     subPath: projects
     readOnly: true
```

One reason that we strongly recommend this approach is that it will
be compatible with improvements coming in 5.5.2. In this version,
the `tools` volume will be `managed` alongside `projects`,
`environments`, and `gallery`. This will simplify installing and
updating new tools; e.g., by eliminating the need to manually toggle
between read-only and read-write mode.

# Recommendation: system storage

If you can install an NFS service on the master node of a Gravity-based
AE5 cluster, you can simply leverage the existing `/opt/anaconda`
volume. To prepare the volume for this purpose, follow these steps:

1. Install the NFS server package for your host operating system, start
   the service, and configure it to automatically start on reboot.
2. Create a directory `/opt/anaconda/tools`, and give it the same
   permissions as `/opt/anaconda/storage`. Note the UID and GID of the
   directory, which will be used below.
3. Create an entry in the /etc/exports file which exports this directory
   to all AE5 nodes. We recommend using the `all_squash` option, and set
   `anonuid` and `anongid` to be equal to the UID and GID set in step 2.
   For example, your `/etc/exports` line might look like this:
   ```
   /opt/anaconda/tools 10.138.148.*(rw,async,all_squash,anonuid=1000,anongid=1000)
   ```
4. Activate this new export by running the command `exportfs -a` as root.

With a volume such as this, the volume specification might look as follows,
but of course with a different server address and possibly a different `groupID`.
```
volumes:
   /tools:
     groupID: 1000
     nfs:
       path: /opt/anaconda/tools
       server: 10.138.148.187
       readOnly: true
```

# Completing the volume addition

As instructed in our documentation, certain system pods must be
restarted once a new volume is added to the ConfigMap. Specifically,
those instructions call for a restart of both the `workspace` and
`deploy` pods. However, because this volume is only useful for user
sessions, we can in fact restart only the `workspace` pod:
```
kubectl get pods | grep ap-workspace | \
    cut -d ' ' -f 1 | xargs kubectl delete pod
```
Once the workspace pod has stabilized, create a new project in AE5,
using the R project type. Launch a session using either Jupyter or
JupyterLab, and open a terminal window. Manually confirm that the
directory `/tools` exists. If you have set `readOnly: false` in
preparation for installation, make sure the directory is writable.

