# Compliance Checklist

## Checklist

| ID | Area | Requirement | Evidence | Owner |
| --- | --- | --- | --- | --- |
| ACC-01 | Accounts | Every grant of access to a production system is made by assigning a role, never by granting a permission to an individual directly. | Quarterly export of role assignments from the identity provider, filed in the compliance drive. | Priya Raman |
| ACC-02 | Accounts | Every account holding a privileged role is reviewed each quarter by the owner of the system it reaches, and a review that is not completed within the quarter removes the privilege automatically. | Signed quarterly review record per production system. | Priya Raman |
| ACC-03 | Accounts | Every account with access to a production system or to customer data authenticates with a second factor, and a factor that is an SMS message does not count as one. | Identity provider report listing enrolled factors per account. | Priya Raman |
| ACC-05 | Accounts | Access for a leaver is revoked within one working day of their last day, and within one hour where the departure is involuntary. | Leaver ticket with revocation timestamps attached. | Priya Raman |
| DAT-01 | Data | Operational logs are retained for 90 days and deleted automatically thereafter, with no manual extension available to any individual. | Retention configuration export from the log platform. | Ayo Adeyemi |
| DAT-02 | Data | Access logs are retained for 400 days so that a full year of activity remains available to an investigation, and are protected from deletion by any operational process. | Retention configuration export plus quarterly integrity check. | Ayo Adeyemi |
| DAT-03 | Data | A subject access request is answered within the 30 day statutory period, against an internal target of 10 days. | Request register with received and answered dates. | Ayo Adeyemi |
| DAT-05 | Data | A field holding personal data is collected only where a named purpose requires it, and the purpose is recorded in the data inventory before collection begins. | Data inventory entries with purpose and legal basis. | Ayo Adeyemi |
| OPS-01 | Operations | A change reaching production carries at least one approving review from somebody who did not write it, and a change touching a shared schema carries two. | Pull request records showing approvals per production change. | Takeshi Mori |
| OPS-02 | Operations | Every alert that requires a human routes to the on-call rota rather than to an individual or to a mailbox, and an alert with no documented action is removed rather than muted. | Alert routing export with owner and runbook link per alert. | Takeshi Mori |
| OPS-03 | Operations | The incident process is exercised at least twice a year with a scenario nobody taking part has seen in advance. | Exercise report including timeline and follow-up actions. | Takeshi Mori |
| OPS-04 | Operations | Every deploy can be reversed by a pipeline action without a manual edit, and a change that cannot be reversed that way is released behind a flag instead. | Pipeline configuration plus quarterly rollback drill record. | Takeshi Mori |
| OPS-05 | Operations | Every production service reports the four golden signals, and a service that reports none of them is not considered in production. | Monitoring coverage report listing signals per service. | Takeshi Mori |
| SEC-01 | Security | Application secrets, private keys and service credentials are stored in the managed vault and read at runtime, never committed to a repository or written into a configuration file. | Repository scan report showing zero secret findings. | Hannah Steiner |
| SEC-02 | Security | All traffic between services, and all traffic leaving the platform, uses TLS 1.2 or later with certificates issued by the internal authority. | Quarterly TLS inventory with cipher and version per endpoint. | Hannah Steiner |
| SEC-03 | Security | Every store holding customer data is encrypted at rest with keys managed by the platform key service, and keys are rotated annually. | Key service rotation log and per-store encryption attestation. | Hannah Steiner |
| SEC-04 | Security | Every employee and long-term contractor completes security awareness training within 30 days of joining and once every year after that. | Training completion export from the learning system. | Hannah Steiner |

## Withdrawn

- ACC-04 (superseded by ACC-01)
- DAT-04 (superseded by OPS-04)
- SEC-05 (superseded by SEC-02)

## Coverage

| Area | Active | Withdrawn |
| --- | --- | --- |
| Accounts | 4 | 1 |
| Data | 4 | 1 |
| Operations | 5 | 0 |
| Security | 4 | 1 |
| All areas | 17 | 3 |

## Uncovered controls

- C-08 Backup restoration testing
- C-11 Vendor risk assessment
- C-15 Business continuity plan
