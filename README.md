# cloud-iac

## Azure architecture

a general architectural view

```mermaid
flowchart LR
    Internet((Internet)) --> PIP[Standard public IP]
    PIP --> LB[Standard Load Balancer<br/>TCP 80]

    subgraph RG[Resource group: shopify-ms<br/>East US]
        subgraph VNet[Virtual network: 10.0.0.0/16]
            subgraph WebSubnet[Public subnet: 10.0.1.0/24]
                WebVM[E-commerce Linux VM<br/>NIC in LB backend pool]
            end
            subgraph AppSubnet[Private subnet: 10.0.2.0/24]
                SalesVM[Sales Linux VM]
            end
            subgraph RedisSubnet[Redis private-endpoint subnet: 10.0.3.0/24]
                RedisPE[Redis private endpoint]
            end
            subgraph AcrSubnet[ACR private-endpoint subnet: 10.0.4.0/24]
                AcrPE[ACR private endpoint]
            end
            subgraph DbSubnet[PostgreSQL delegated subnet: 10.0.5.0/24]
                PostgreSQL[PostgreSQL Flexible Server<br/>sales-db]
            end
        end

        Redis[Azure Cache for Redis<br/>Standard, TLS only, public access disabled]
        ACR[Azure Container Registry<br/>Premium, public access disabled]
        KeyVault[Azure Key Vault<br/>ACR customer-managed key]
        Identity[User-assigned identity<br/>ACR encryption]
        RedisDNS[Private DNS<br/>privatelink.redis.cache.windows.net]
        AcrDNS[Private DNS<br/>privatelink.azurecr.io]
        PgDNS[Private DNS<br/>privatelink.postgres.database.azure.com]
    end

    LB --> WebVM
    SalesVM -->|PostgreSQL / 5432| PostgreSQL
    SalesVM -->|TLS / 6380| RedisPE
    RedisPE --> Redis
    WebVM -.->|Private route exists; image pull not configured| AcrPE
    SalesVM -.->|Private route exists; image pull not configured| AcrPE
    AcrPE --> ACR
    ACR -->|CMK| KeyVault
    Identity -->|Encryption access| KeyVault
    RedisDNS --- VNet
    AcrDNS --- VNet
    PgDNS --- VNet
```

### Notes

- The public IP fronts the load balancer; the web VM NIC has no direct public IP.
- PostgreSQL uses its delegated subnet and private DNS. The app subnet remains
  separate so the sales VM is not placed in a PostgreSQL-only delegated subnet.
- Redis and ACR are private-only and have private endpoints plus VNet-linked
  private DNS zones.
- Set globally unique `acr_registry_name` and `acr_key_vault_name` values, and
  provide `postgres_administrator_password` securely when planning/applying.
