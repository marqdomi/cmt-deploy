# CMT Network Access Requirements
## Azure Container Apps → Solera F5 Network

**Date:** December 12, 2025  
**Application:** Certificate Management Tool (CMT)  
**Azure Region:** Central US

---

## 🔷 AZURE SIDE - Outbound IPs (Source)

The Container Apps Environment uses **shared outbound IPs**. The following IPs may be used when CMT connects to Solera F5 devices:

### Primary Outbound IP Ranges (Allow on Solera Firewall)

```
# Azure Central US - Container Apps Outbound
40.89.240.0/24      # 40.89.240.243, 40.89.240.113
13.89.111.0/24      # 13.89.111.127, 13.89.111.197
64.236.112.0/23     # 64.236.112.x, 64.236.113.x
172.169.204.0/22    # 172.169.204.x - 172.169.207.x
172.168.41.0/24     # 172.168.41.166
172.168.140.0/24    # 172.168.140.9
135.233.59.0/24     # 135.233.59.18
135.233.67.0/24     # 135.233.67.x
135.233.107.0/24    # 135.233.107.143
52.228.167.0/24     # 52.228.167.121, 52.228.167.149
52.230.237.0/24     # 52.230.237.x
72.152.60.0/24      # 72.152.60.23
130.131.144.0/24    # 130.131.144.244
128.203.166.0/24    # 128.203.166.10
128.203.236.0/24    # 128.203.236.234
64.236.74.0/24      # 64.236.74.84, 64.236.75.41
20.84.193.0/24      # 20.84.193.x
20.84.194.0/24      # 20.84.194.4
104.43.193.0/24     # 104.43.193.x
104.43.202.0/24     # 104.43.202.40
104.43.204.0/24     # 104.43.204.253
104.43.206.0/24     # 104.43.206.x
104.208.32.0/24     # 104.208.32.103
40.77.64.0/20       # 40.77.64.x - 40.77.80.x
40.83.16.0/24       # 40.83.16.22, 40.83.21.214
```

### Full List of Individual Outbound IPs

<details>
<summary>Click to expand (77 IPs)</summary>

```
40.89.240.243
13.89.111.127
64.236.113.15
64.236.112.134
64.236.112.251
64.236.113.32
64.236.112.119
64.236.113.23
64.236.112.111
64.236.112.120
64.236.112.221
64.236.112.237
13.89.111.197
172.169.207.227
172.169.205.144
172.168.41.166
135.233.107.143
172.169.206.100
172.169.187.35
172.169.206.55
172.169.58.181
172.169.63.30
172.169.63.29
40.89.240.113
172.169.58.116
172.169.63.35
135.233.59.18
52.228.167.121
72.152.60.23
130.131.144.244
52.228.167.149
52.230.237.13
52.230.237.16
52.230.237.27
52.230.237.18
52.230.237.21
52.230.237.9
20.84.194.4
20.84.193.62
104.43.206.195
104.43.193.31
104.43.193.12
104.43.206.255
104.208.32.103
104.43.202.40
104.43.193.29
104.43.204.253
104.43.193.0
104.43.193.5
20.84.193.84
40.77.66.51
40.83.16.22
40.83.21.214
40.77.64.230
40.77.68.211
40.77.66.213
40.77.80.56
40.77.71.108
40.77.71.6
40.77.68.109
20.84.193.40
135.233.67.211
135.233.67.95
135.233.67.231
135.233.67.96
135.233.67.204
135.233.67.160
64.236.75.41
128.203.166.10
64.236.74.84
128.203.236.234
172.169.204.243
172.169.205.18
172.169.204.172
172.169.204.186
172.169.204.232
172.169.204.225
172.168.140.9
```

</details>

---

## 🔶 SOLERA SIDE - F5 Destination Subnets

CMT needs to reach the following F5 BIG-IP management interfaces via **HTTPS (TCP/443)**:

### Summary by Site & Subnet

| Site | Location | Subnet | IP Range | # Devices | Protocol |
|------|----------|--------|----------|-----------|----------|
| **US-DC01** | US Datacenter 1 | `10.119.0.0/24` | 10.119.0.75-91 | 18 | HTTPS/443 |
| **US-DC01** | US Datacenter 1 | `10.132.3.0/24` | 10.132.3.252-253 | 2 | HTTPS/443 |
| **US-DC02** | US Datacenter 2 | `10.119.8.0/24` | 10.119.8.75-89 | 12 | HTTPS/443 |
| **EU-DC01** | Europe DC 1 | `10.119.16.0/24` | 10.119.16.75-91 | 14 | HTTPS/443 |
| **EU-DC02** | Europe DC 2 | `10.119.24.0/24` | 10.119.24.75-91 | 14 | HTTPS/443 |
| **AU-DC10** | Australia DC | `10.119.35.0/24` | 10.119.35.50-51 | 2 | HTTPS/443 |
| **BE-DC01** | Belgium DC | `10.119.34.0/24` | 10.119.34.8-9 | 2 | HTTPS/443 |
| **RU-DC10** | Russia DC | `10.119.36.0/24` | 10.119.36.50-51 | 2 | HTTPS/443 |
| **RU-DC10** | Russia DC (Legacy) | `172.20.188.0/24` | 172.20.188.52-53 | 2 | HTTPS/443 |
| **SG-DC10** | Singapore DC | `10.119.37.0/24` | 10.119.37.50-51 | 2 | HTTPS/443 |
| **OT-DC01** | Omnitracs DC1 | `192.168.13.0/24` | 192.168.13.5-103 | 24 | HTTPS/443 |
| **OT-DC02** | Omnitracs DC2 | `192.168.52.0/24` | 192.168.52.181-187 | 7 | HTTPS/443 |
| **AWS-IE** | AWS Ireland | `34.241.100.251/32` | Single IP | 1 | HTTPS/443 |

### Detailed F5 Device List by Subnet

#### 10.119.0.0/24 - US-DC01 (18 devices)
```
10.119.0.75  - usdc01-fab1-lb-001 (vCMP Host)
10.119.0.76  - usdc01-fab1-lb-002 (vCMP Host)
10.119.0.77  - usdc01-fab1-lb-003 (i4800)
10.119.0.78  - usdc01-fab1-lb-004 (i4800)
10.119.0.80  - USDC01-LB01-BLUE-PRI (vCMP Guest)
10.119.0.81  - USDC01-LB02-BLUE-SEC (vCMP Guest)
10.119.0.82  - usdc01-fab1-lb-001-black (vCMP Guest)
10.119.0.83  - USDC01-LB02-BLACK-SEC (vCMP Guest)
10.119.0.84  - usdc01-fab1-lb-001-white (vCMP Guest)
10.119.0.85  - usdc01-fab1-lb-002-white (vCMP Guest)
10.119.0.86  - USDC01-LB01-GRPUR-PRI (vCMP Guest)
10.119.0.87  - USDC01-LB02-GRPUR-SEC (vCMP Guest)
10.119.0.88  - USDC01-LB01-BLUENP-PRI (vCMP Guest)
10.119.0.89  - USDC01-LB02-BLUENP-SEC (vCMP Guest)
10.119.0.90  - usdc01-fab1-lb-001-black-nonprod (vCMP Guest)
10.119.0.91  - usdc01-fab1-lb-002-black-nonprod (vCMP Guest)
```

#### 10.132.3.0/24 - US-DC01 Extended (2 devices)
```
10.132.3.252 - usdc01-fab1-lb-006 (Virtual Edition)
10.132.3.253 - usdc01-fab1-lb-005 (Virtual Edition)
```

#### 10.119.8.0/24 - US-DC02 (12 devices)
```
10.119.8.75  - usdc02-fab1-lb-001 (vCMP Host)
10.119.8.76  - usdc02-fab1-lb-002 (vCMP Host)
10.119.8.80  - usdc02-fab1-lb-001-blue (vCMP Guest)
10.119.8.81  - usdc02-fab1-lb-002-blue (vCMP Guest)
10.119.8.82  - usdc02-fab1-lb-001-black (vCMP Guest)
10.119.8.83  - usdc02-fab1-lb-002-black (vCMP Guest)
10.119.8.84  - usdc02-fab1-lb-001-white (vCMP Guest)
10.119.8.85  - usdc02-fab1-lb-002-white (vCMP Guest)
10.119.8.86  - usdc02-fab1-lb-001-grpur (vCMP Guest)
10.119.8.87  - usdc02-fab1-lb-002-grpur (vCMP Guest)
10.119.8.88  - usdc02-fab1-lb-001-rell-npd (vCMP Guest)
10.119.8.89  - usdc02-fab1-lb-002-rell-npd (vCMP Guest)
```

#### 10.119.16.0/24 - EU-DC01 (14 devices)
```
10.119.16.75 - eudc01-lb-001-vcmp (vCMP Host)
10.119.16.76 - eudc01-lb-002-vcmp (vCMP Host)
10.119.16.80 - eudc01-lb-001-blue (vCMP Guest)
10.119.16.81 - eudc01-lb-002-blue (vCMP Guest)
10.119.16.82 - eudc01-lb-001-black (vCMP Guest)
10.119.16.83 - eudc01-lb-002-black (vCMP Guest)
10.119.16.84 - eudc01-lb-001-white (vCMP Guest)
10.119.16.85 - eudc01-lb-002-white (vCMP Guest)
10.119.16.86 - eudc01-lb-001-greenpurple (vCMP Guest)
10.119.16.87 - eudc01-lb-002-greenpurple (vCMP Guest)
10.119.16.88 - eudc01-lb-001-nonprod (vCMP Guest)
10.119.16.89 - eudc01-lb-002-nonprod (vCMP Guest)
10.119.16.90 - eudc01-lb-001-test (vCMP Guest)
10.119.16.91 - eudc01-lb-002-test (vCMP Guest)
```

#### 10.119.24.0/24 - EU-DC02 (14 devices)
```
10.119.24.75 - eudc02-lb-001-vcmp (vCMP Host)
10.119.24.76 - eudc02-lb-002-vcmp (vCMP Host)
10.119.24.80 - eudc02-lb-001-blue (vCMP Guest)
10.119.24.81 - eudc02-lb-002-blue (vCMP Guest)
10.119.24.82 - eudc02-lb-001-black (vCMP Guest)
10.119.24.83 - eudc02-lb-002-black (vCMP Guest)
10.119.24.84 - eudc02-lb-001-white (vCMP Guest)
10.119.24.85 - eudc02-lb-002-white (vCMP Guest)
10.119.24.86 - eudc02-lb-001-greenpurple (vCMP Guest)
10.119.24.87 - eudc02-lb-002-greenpurple (vCMP Guest)
10.119.24.88 - eudc02-lb-001-nonprod (vCMP Guest)
10.119.24.89 - eudc02-lb-002-nonprod (vCMP Guest)
10.119.24.90 - eudc02-lb-001-test (vCMP Guest)
10.119.24.91 - eudc02-lb-002-test (vCMP Guest)
```

#### 10.119.34.0/24 - BE-DC01 (2 devices)
```
10.119.34.8  - bedc01-fab1-lb-001 (Virtual Edition)
10.119.34.9  - bedc01-fab1-lb-002 (Virtual Edition)
```

#### 10.119.35.0/24 - AU-DC10 (2 devices)
```
10.119.35.50 - audc10-fab1-lb-001 (Virtual Edition)
10.119.35.51 - audc10-fab1-lb-002 (Virtual Edition)
```

#### 10.119.36.0/24 - RU-DC10 (2 devices)
```
10.119.36.50 - rudc10-lb-001 (Virtual Edition)
10.119.36.51 - rudc10-lb-002 (Virtual Edition)
```

#### 10.119.37.0/24 - SG-DC10 (2 devices)
```
10.119.37.50 - sgdc10-fab1-lb-001 (Virtual Edition)
10.119.37.51 - sgdc10-fab1-lb-002 (Virtual Edition)
```

#### 172.20.188.0/24 - RU-DC10 Legacy (2 devices)
```
172.20.188.52 - axrudc10lb150 (i2600)
172.20.188.53 - axrudc10lb151 (i2600)
```

#### 192.168.13.0/24 - Omnitracs DC1 (24 devices)
```
192.168.13.5   - dc1-f5-xrs-int-01
192.168.13.6   - dc1-f5-xrs-int-02
192.168.13.11  - dc1-sag-dev-01
192.168.13.12  - dc1-sag-tst-01
192.168.13.13  - dc1-sag-prd-01
192.168.13.14  - dc1-sag-acpt-01
192.168.13.15  - dc1-sag-prd-02
192.168.13.16  - dc1-sag-tst-02
192.168.13.17  - dc1-f5-xrs-prod-01
192.168.13.18  - dc1-f5-xrs-prod-02
192.168.13.20  - dc1-asm-prd-01
192.168.13.35  - dc1-apm-dev-01
192.168.13.48  - dc1-sag-intp-01
192.168.13.49  - dc1-sag-intp-02
192.168.13.53  - dc1-f5-xrs-int-03
192.168.13.54  - dc1-f5-xrs-int-04
192.168.13.100 - dc1-pem-01
192.168.13.101 - dc1-pem-02
192.168.13.102 - dc1-pem-api-01
192.168.13.103 - dc1-pem-api-02
```

#### 192.168.52.0/24 - Omnitracs DC2 (7 devices)
```
192.168.52.181 - na-oec-02-internal-prod-01
192.168.52.182 - na-oec-02-internal-prod-02
192.168.52.183 - na-oec-02-internal-acpt-01
192.168.52.184 - na-oec-02-internal-acpt-02
192.168.52.185 - na-oec-02-sag-dev-01
192.168.52.186 - na-oec-02-sag-test-01
192.168.52.187 - na-oec-02-test-pcrf-01
```

#### AWS Ireland (1 device)
```
34.241.100.251 - ip-10-32-0-115.monitor.smartdrivesystems.com
```

---

## 📋 Firewall Rules Summary

### From Azure → Solera (ALLOW)

| Rule | Source | Destination | Port | Protocol | Description |
|------|--------|-------------|------|----------|-------------|
| 1 | Azure Outbound IPs* | 10.119.0.0/24 | 443 | TCP | US-DC01 F5s |
| 2 | Azure Outbound IPs* | 10.119.8.0/24 | 443 | TCP | US-DC02 F5s |
| 3 | Azure Outbound IPs* | 10.119.16.0/24 | 443 | TCP | EU-DC01 F5s |
| 4 | Azure Outbound IPs* | 10.119.24.0/24 | 443 | TCP | EU-DC02 F5s |
| 5 | Azure Outbound IPs* | 10.119.34.0/24 | 443 | TCP | BE-DC01 F5s |
| 6 | Azure Outbound IPs* | 10.119.35.0/24 | 443 | TCP | AU-DC10 F5s |
| 7 | Azure Outbound IPs* | 10.119.36.0/24 | 443 | TCP | RU-DC10 F5s |
| 8 | Azure Outbound IPs* | 10.119.37.0/24 | 443 | TCP | SG-DC10 F5s |
| 9 | Azure Outbound IPs* | 10.132.3.252/31 | 443 | TCP | US-DC01 VE F5s |
| 10 | Azure Outbound IPs* | 172.20.188.52/31 | 443 | TCP | RU-DC10 Legacy F5s |
| 11 | Azure Outbound IPs* | 192.168.13.0/24 | 443 | TCP | Omnitracs DC1 F5s |
| 12 | Azure Outbound IPs* | 192.168.52.0/24 | 443 | TCP | Omnitracs DC2 F5s |
| 13 | Azure Outbound IPs* | 34.241.100.251/32 | 443 | TCP | AWS Ireland F5 |

*See "Azure Outbound IPs" section above for complete list

---

## 🔧 Azure VNet Configuration

**Current Setup:** The Container Apps Environment is deployed **without VNet integration** (shared infrastructure).

### Considerations for VPN/ExpressRoute

If you need to establish a direct connection via VPN or ExpressRoute:

1. **Create a new Container Apps Environment with VNet integration:**
   ```bash
   # Create a dedicated VNet
   az network vnet create \
     --name vnet-certmgr-prd-usc \
     --resource-group rg-netops-certmgr-prd-usc \
     --location centralus \
     --address-prefix 10.200.0.0/16

   # Create infrastructure subnet (minimum /23)
   az network vnet subnet create \
     --name snet-cae-infra \
     --vnet-name vnet-certmgr-prd-usc \
     --resource-group rg-netops-certmgr-prd-usc \
     --address-prefixes 10.200.0.0/23
   ```

2. **Re-create Container Apps Environment with VNet:**
   ```bash
   az containerapp env create \
     --name cae-certmgr-prd-usc-vnet \
     --resource-group rg-netops-certmgr-prd-usc \
     --location centralus \
     --infrastructure-subnet-resource-id <subnet-id>
   ```

3. **Configure VPN Gateway or ExpressRoute** to connect Azure VNet to Solera network.

---

## 📊 Statistics

| Metric | Value |
|--------|-------|
| **Total F5 Devices** | 102 |
| **Unique Subnets** | 13 |
| **Sites** | 12 |
| **Regions** | 7 (US, EU, AU, BE, RU, SG, AWS) |
| **Azure Outbound IPs** | 77 |
| **Required Port** | TCP/443 (HTTPS) |

---

## ⚠️ Important Notes

1. **Azure Outbound IPs can change** - Container Apps uses shared outbound IPs that may change. For a stable solution, consider VNet integration with NAT Gateway.

2. **F5 iControl REST API** - CMT connects to F5 devices via HTTPS (port 443) using the iControl REST API.

3. **DNS Resolution** - Ensure Azure can resolve Solera hostnames, or configure private DNS zones.

4. **Authentication** - F5 devices use local authentication. Credentials are stored encrypted in CMT's database.

---

*Generated: December 12, 2025*
