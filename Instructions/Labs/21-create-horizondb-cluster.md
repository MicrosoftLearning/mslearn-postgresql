---
lab:
  title: Create an Azure HorizonDB cluster
  module: Get started with Azure HorizonDB
  description: In this exercise, you create an Azure HorizonDB cluster in the Azure portal, allow your client to connect, and use psql from Azure Cloud Shell to run your first query.
  duration: 30
  level: 100
  islab: true
  status: 'in-development' # in-development or released
  targetDate: '2026-10-15' # Set to the future date when you expect an in-development lab to be released
---

# Create an Azure HorizonDB cluster

Now that you know what Azure HorizonDB is and how it works, put the concepts into practice. In this exercise, you create an Azure HorizonDB cluster in the Azure portal, allow your client to connect, and use `psql` from Azure Cloud Shell to run your first query.

> [!NOTE]
> Azure HorizonDB is in preview. Some fields and defaults in the Azure portal might change. If a specific option isn't available in your subscription or region, use the closest equivalent value listed here.

## Before you start

To complete this exercise, you need:

- An [Azure subscription](https://azure.microsoft.com/pricing/purchase-options/azure-account?cid=msft_learn) with permissions to create resources.
- Access to a region where Azure HorizonDB is available, such as **East US**, **West US 3**, **Sweden Central**, or **Australia East**.

## Create an Azure HorizonDB cluster

Start by creating a new cluster with the default two-replica, zone-redundant configuration. This gives you a writable primary and one readable standby that share the same zone-resilient storage.

1. Open a web browser and sign in to the [Azure portal](https://portal.azure.com).
1. In the upper-left corner, select **Create a resource**.
1. Under **Categories**, select **Databases**, and then find and select **Azure HorizonDB**.
1. Select **Create**.
1. On the **Basics** tab, enter the following **Project details**:

    | Setting | Value |
    |---|---|
    | **Subscription** | *your subscription* |
    | **Resource group** | Select **Create new** and enter `rg-horizondb-lab` |

1. Under **Cluster details**, enter the following values:

    | Setting | Value |
    |---|---|
    | **Cluster name** | `horizondb-lab-<yourinitials><random-number>` |
    | **Region** | A region that supports Azure HorizonDB, such as **East US** |
    | **PostgreSQL version** | *Accept the default (17)* |

    The cluster name must be unique within your subscription and resource group. Add your initials and a small random number to avoid collisions.

1. Under **Compute details**, select **Configure** and set:

    | Setting | Value |
    |---|---|
    | **vCores** | **2** |
    | **High availability** | **Zone redundant** |
    | **Readable high availability replicas** | **1** |

    Select **Save**.

    This is the smallest configuration that still provides zone resilience — a primary and one readable standby that share storage.

1. Under **Authentication**, enter the following values:

    | Setting | Value |
    |---|---|
    | **Authentication method** | **PostgreSQL authentication only** |
    | **Admin username** | `hdbadmin` |
    | **Password** | *A complex password you'll remember* |
    | **Confirm password** | *The same password* |

    > [!IMPORTANT]
    > Save your admin username and password somewhere safe. You need them to connect to the cluster later.

1. Select **Next: Networking**.
1. On the **Networking** tab, under **Firewall rules**, select **Allow public access from Azure services and resources within Azure to this cluster**. Leave the other firewall settings at their defaults for now.

    This setting lets Azure Cloud Shell connect to your cluster in the next step.

1. Select **Review + create**, review the summary, and then select **Create**.

    Deployment typically takes 5–10 minutes. Wait for the notification that says **Your deployment is complete** before you continue.

1. When deployment finishes, select **Go to resource**.

## Explore your cluster in the portal

Now that the cluster exists, take a moment to see how the components you learned about show up in the portal.

1. On the cluster **Overview** page, review the following properties:
    - **Status** should be **Ready**.
    - **PostgreSQL version** should be **17**.
    - **Read/write endpoint** — the fully qualified name that points to the primary replica. It looks similar to `horizondb-lab-<yourinitials><random-number>.<randomId>.<region>.horizondb.azure.com`.
    - **Read-only endpoint** — a separate endpoint that load-balances connections across the readable replicas.
1. Copy the **read/write endpoint** value. You use it in the next section.
1. In the left menu, select **Replicas** under **Settings**. Confirm that you see two replicas — one primary and one readable standby.

    Because storage is shared, the standby replica was provisioned quickly and doesn't require a data copy.

## Add a firewall rule for your client

Azure services can already reach the cluster because you allowed them during creation. To connect from Azure Cloud Shell, you also need to allow your Cloud Shell session's public IP.

1. In the left menu of your cluster, under **Settings**, select **Networking**.
1. Under **Firewall rules**, select **Add current client IP address**.
1. Select **Save** and wait for the notification that the firewall rules were updated.

## Connect and run a query with psql

Azure Cloud Shell includes the `psql` PostgreSQL client, so you don't need to install anything locally.

1. In the top toolbar of the Azure portal, select the **Cloud Shell** icon (**>_**).
1. If prompted, select **Bash**. If this is your first time using Cloud Shell, follow the prompts to create a storage account.
1. In the Cloud Shell, run the following command. Replace `<endpoint>` with the read/write endpoint you copied earlier, and `<admin-password>` with the password you set:

    ```bash
    psql "host=<endpoint> port=5432 dbname=postgres user=hdbadmin password=<admin-password> sslmode=require"
    ```

    The `sslmode=require` value forces an encrypted connection, which Azure HorizonDB requires.

1. After a successful connection, you see output similar to:

    ```output
    psql (16.12, server 17.9 (Azure HorizonDB (c8e7b717d05)(release)))
    SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, compression: off)
    Type "help" for help.

    postgres=>
    ```

1. At the `postgres=>` prompt, create a small table and insert a few rows. Enter each statement and press Enter:

    ```sql
    CREATE TABLE devices (
        id serial PRIMARY KEY,
        name text NOT NULL,
        region text NOT NULL
    );
    ```

    ```sql
    INSERT INTO devices (name, region) VALUES
        ('sensor-01', 'east-us'),
        ('sensor-02', 'east-us'),
        ('sensor-03', 'west-us-3');
    ```

1. Query the table to confirm the data was written and read back correctly:

    ```sql
    SELECT region, COUNT(*) AS device_count
    FROM devices
    GROUP BY region
    ORDER BY region;
    ```

    You should see two rows, with `east-us` reporting two devices and `west-us-3` reporting one. These reads and writes went through the read/write endpoint, which always points to the primary replica.

1. Exit `psql`:

    ```sql
    \q
    ```

Great — you created a fully managed, PostgreSQL-compatible cluster, connected to it securely, and ran your first query.

## Clean up

If you've finished exploring, delete the resources you created to avoid ongoing Azure charges.

1. In the Azure portal, open the resource group `rg-horizondb-lab`.
1. On the toolbar, select **Delete resource group**.
1. Enter the resource group name to confirm, and then select **Delete**.

Deleting the resource group removes the Azure HorizonDB cluster and all associated storage.
