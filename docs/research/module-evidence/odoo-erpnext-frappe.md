# Module ownership evidence: Odoo, ERPNext/Frappe, Frappe CRM, Frappe HR, Frappe Helpdesk

Method: shallow sparse clones of `odoo/odoo` (branch `18.0`), `frappe/erpnext` (branch `version-15`), `frappe/frappe` (branch `version-15`), `frappe/crm`, `frappe/hrms`, `frappe/helpdesk` (default branches) into `/tmp/research/*`, read live at fetch time 2026-09-24. All claims below are read directly from manifests (`__manifest__.py`, `hooks.py`, `pyproject.toml`), DocType JSON `module` fields, and model source (`_name`/`_inherit`). No Russian sources used. Earlier file `docs/research/finance-first-evidence/odoo-erpnext.md` was used only to identify which files to re-check; nothing from it was copied without re-verifying against source in this pass.

Labels used: **source** (I read the code/doc myself, quoted below), **inferred** (a conclusion drawn from source but not itself a literal quote), **NOT FOUND** (checked and absent, or out of reach).

---

## Odoo 18 (Community, `odoo/odoo` @ `18.0`)

### Q1. Top-level modules/apps and installability

Label: source. Odoo ships one monorepo of ~addons, each with its own `__manifest__.py` and `depends` list; any addon with `installable: True` can in principle be installed alone if its `depends` are satisfied, but most business apps pull in a shared base.

- `addons/sale/__manifest__.py`: `'depends': ['sales_team', 'account_payment', 'utm']` — Sales depends on `account_payment` (which pulls in `account`, `payment`, `portal`), so **Sales cannot be installed without Accounting**.
- `addons/crm/__manifest__.py`: `'depends': ['base_setup', 'sales_team', 'mail', 'calendar', 'resource', 'utm', 'web_tour', 'contacts', 'digest', 'phone_validation']` — **no dependency on `sale` or `account`**. CRM installs standalone.
- `addons/project/__manifest__.py`: `'depends': ['analytic', 'base_setup', 'mail', 'portal', 'rating', 'resource', 'web', 'web_tour', 'digest']` — depends on `analytic` (the accounting analytic-account model) but **not on `sale` or `account`**; Project installs standalone.
- `addons/account/__manifest__.py`: `'depends': ['base_setup', 'onboarding', 'product', 'analytic', 'portal', 'digest']` — Accounting (`account`, product name "Invoicing") has no dependency on `sale`, `crm`, or `project`.
- `addons/point_of_sale/__manifest__.py`: `'depends': ['stock_account', 'barcodes', 'web_editor', 'digest', 'phone_validation']` — POS depends on `stock_account` (which pulls in `account`), **not on `sale`**.
- `addons/website_sale/__manifest__.py`: `'depends': ['website', 'sale', 'website_payment', 'website_mail', 'portal_rating', 'digest', 'delivery']` — eCommerce explicitly **depends on `sale`**.
- `addons/contacts/__manifest__.py`: `'depends': ['base', 'mail']`.
- The bridge module `addons/sale_crm/__manifest__.py`: `'depends': ['sale', 'crm']`, `'auto_install': True` — a separate glue addon that only exists (and auto-installs) when *both* Sales and CRM are present.
- Enterprise-only modules (`account_asset` for fixed-asset depreciation, `documents` for DMS, `sale_subscription` for recurring billing) are **NOT FOUND** in the public `odoo/odoo` repo: `git ls-tree -d --name-only HEAD -- addons/` at 18.0 has no `account_asset`, `documents`, or `sale_subscription` directories (checked live). Label: source (absence), inferred (these are Enterprise-only, per Odoo's own edition split, not verifiable further from this repo).

### Q2. Records owned per module (doctype/model `_name`)

Label: source, from grepping `_name = '...'` in each addon's models directory (files listed under each app).
- `sale`: `sale.order`, `sale.order.line` (files `sale/models/sale_order.py`, `sale_order_line.py`). Also **extends** `account.move` in place (see Q6).
- `crm`: `crm.lead` (used for both leads and opportunities, distinguished by a `type` field), `crm.team`, `crm.team.member`, `crm.stage`, `crm.lost.reason`, `crm.recurring.plan` (files in `crm/models/`).
- `account`: `account.move` (invoices, bills, journal entries — one unified model), `account.move.line`, plus banking models under `account`/`account_accountant`.
- `point_of_sale`: `pos.order` (own model, not `sale.order`), `pos.session`, `pos.payment` — `point_of_sale/models/pos_order.py:355`: `account_move = fields.Many2one('account.move', string='Invoice', ...)`.
- `project`: `project.project`, `project.task`, `project.milestone`, `project.update` (from manifest data file list: `project_project_views.xml`, `project_task_views.xml`, `project_milestone_views.xml`, `project_update_views.xml`).
- `hr_timesheet`: extends `account.analytic.line` in place rather than a separate timesheet table — `hr_timesheet/models/hr_timesheet.py:14-15`: `class AccountAnalyticLine(models.Model): _inherit = 'account.analytic.line'` (re-confirmed from prior pass, still true at 18.0 HEAD used here).
- `contacts`: does not define a new partner model; it only adds a menu and re-uses `res.partner` from `base` — `contacts/models/res_partner.py`: `class Partner(models.Model): _inherit = "res.partner"`.
- `base` (core, not a business app but the shared foundation): `res.partner` (`_description = 'Contact'`, `odoo/addons/base/models/res_partner.py`), `ir.attachment` (`odoo/addons/base/models/ir_attachment.py:46`: `_name = 'ir.attachment'`, with generic polymorphic link fields `res_model = fields.Char('Resource Model')` and `res_id = fields.Many2oneReference('Resource ID', model_field='res_model')`, lines 413/415).

### Q3. Sales: quotes, orders, customer invoices, and channel landing points

Label: source.
- Quotes and orders are one model, `sale.order` (state field distinguishes `draft`/quotation from `sale`/confirmed order) — owned by the `sale` module (`sale/models/sale_order.py`).
- Customer invoices are `account.move` records with `move_type` set to `out_invoice`. `sale/models/sale_order.py:1516`: `return self.env['account.move'].sudo().with_context(default_move_type='out_invoice').create(invoice_vals_list)`, called from `_create_invoices` (line 1518). So **Sales creates the invoice, but the invoice's model (`account.move`) is defined by `account`**, not by `sale` — Sales only extends it (see Q6).
- Channels and where they land:
  - **CRM lead/opportunity → quotation**: not done inside `crm` itself. The bridge module `sale_crm` (`depends: ['sale', 'crm']`, `auto_install: True`) adds `order_ids = fields.One2many('sale.order', 'opportunity_id', ...)` on `crm.lead` (`sale_crm/models/crm_lead.py:16`) and extends `sale.order` (`sale_crm/models/sale_order.py:8`: `_inherit = 'sale.order'`) to add the `opportunity_id` back-link. **CRM does not own or create `sale.order` records** — it only gets a convenience link once `sale_crm` is installed.
  - **POS**: lands in `pos.order`, a distinct model owned by `point_of_sale`, not `sale.order`. It creates its own `account.move` invoice directly when needed (`point_of_sale/models/pos_order.py:748`: `invoice = self.env['account.move'].sudo()...`) — POS depends on `stock_account`→`account`, **not on `sale`**.
  - **eCommerce (website_sale)**: lands in `sale.order` — `website_sale/models/sale_order.py:18`: `_inherit = 'sale.order'`. `website_sale` explicitly `depends: ['website', 'sale', ...]`, so it is a channel that extends the Sales model rather than owning its own order.
  - **Subscriptions**: `sale_subscription` is Enterprise-only and **NOT FOUND** in this public repo (see Q1); cannot confirm structurally here, only that it is absent from Community.
  - **Invoice created directly in Accounting with no order**: structurally possible — `account.move` (`account/models/account_move.py`) has no required link to a `sale.order`; `invoice_origin` (`account/models/account_move.py:648`) is an optional free-text field, not a foreign key requiring a sales order. Label: inferred from field definition (nullable/optional field, no FK constraint found).
  - **Sale of a fixed asset**: the fixed-asset module (`account_asset`) is Enterprise-only and **NOT FOUND** in `odoo/odoo`; the mechanism for asset-disposal invoicing could not be verified from this public repo.

### Q4. CRM: what it owns, does it create sales/finance documents

Label: source.
- CRM owns `crm.lead` (dual-purpose lead/opportunity), `crm.team`, `crm.stage`, `crm.lost.reason`, `crm.recurring.plan` — all defined inside `crm/models/`.
- Grep across the entire `crm` addon for any reference to `sale.order` or `sale_order` returned **no matches** (`grep -rl "sale.order\|sale_order" crm/` → none). CRM's own code has zero knowledge of Sales.
- CRM does **not** create finance documents (`account.move`) either — no such reference in `crm/models/`.
- The hand-off to Sales exists only via the separate, optional bridge addon `sale_crm` (see Q3), which is a distinct installable unit (`auto_install: True` only when both `sale` and `crm` are present). This confirms CRM's role is lead/opportunity capture and qualification; it hands off to Sales through an integration layer rather than owning or creating quotations/orders itself.

### Q5. Projects: does it own records or is it a dimension/view?

Label: source.
- `project` (base module) does own real records: `project.project`, `project.task`, `project.milestone`, `project.update` — these are genuine business records (task assignment, stage, deadlines), not just a view.
- However, project **profitability/billing linkage to money is not native to `project`** — it is layered on through `analytic` (shared with Accounting) and through separate bridge addons:
  - `project/__manifest__.py` depends on `analytic` (the accounting analytic-account model), and the profitability hook `_get_profitability_items` lives in `project/models/project_project.py:899` as a base method that other addons override.
  - `sale_project/__manifest__.py`: `'depends': ['sale_management', 'sale_service', 'project_account']` — a distinct addon that adds Sales-Order-driven task generation and invoicing on top of Project; it overrides `_get_profitability_items` (`sale_project/models/project_project.py:759`) to add invoice/vendor-bill lines sourced from `sale`/`purchase`, not from Project's own tables.
  - `sale_timesheet/__manifest__.py`: `'depends': ['sale_project', 'hr_timesheet']` — timesheets (which are `account.analytic.line` rows, owned structurally by the shared `analytic` model) get billed through Sales, not through Project.
  - Budgets: Odoo's budgeting module (`account_budget`) is Enterprise-only and **NOT FOUND** in `odoo/odoo`; whether Project ever owns a budget record could not be verified in Community source.
- Conclusion (inferred from the above): Project owns tasks/milestones/updates as first-class records, but money-facing project data (billing, profitability, cost) is assembled by reading `account.analytic.line`/`account.move` records that live in Accounting/Sales via the analytic account, i.e., Project acts partly as a **dimension/rollup view over Accounting and Sales records** for the financial side, while remaining the owner of the task/milestone records themselves.

### Q6. Accounting: what it owns; is the customer invoice an `account.move` owned by Accounting even when Sales creates it?

Label: source. Yes.
- `account/models/account_move.py:162`: `move_type = fields.Selection(...)` and the model is defined with `_name = 'account.move'` in the `account` module — this is the base definition (invoices, vendor bills, journal entries, credit notes are all `account.move` records distinguished by `move_type`).
- Confirmed that `sale` **extends** rather than **defines** this model: `sale/models/account_move.py`:
  ```python
  class AccountMove(models.Model):
      _name = 'account.move'
      _inherit = ['account.move', 'utm.mixin']
  ```
  This is Odoo's "extend an existing model" pattern (same `_name`, listed also in `_inherit`) — `sale` adds fields (`team_id`, `campaign_id`) to the already-owned `account.move` model; it does not create a competing model. Bank transactions (`account.bank.statement.line`) are likewise defined under `account`.
- Accounting's `depends` list (`base_setup`, `onboarding`, `product`, `analytic`, `portal`, `digest`) has no dependency on `sale`, confirming Accounting can exist and issue invoices without Sales being installed at all.

### Q7. Documents/DMS module

Label: source (absence) + inferred.
- A dedicated Documents/DMS app (`documents`) exists in Odoo's product line but is **NOT FOUND** in the public `odoo/odoo` Community repo (`git ls-tree -d --name-only HEAD -- addons/` has no `documents` directory at 18.0) — it is Enterprise-only, so its ownership model could not be verified from source here.
- What Community *does* have: attachments are generic. `ir.attachment` (core `base`, `odoo/addons/base/models/ir_attachment.py`) is a single polymorphic table with `res_model`/`res_id` fields (lines 413, 415) that any model's records point to — there is no per-module "document" record; every module (Sales, Accounting, Project, CRM) simply attaches files to its own records via this shared, generic mechanism, not via a documents module owning them.

### Q8. Contacts: shared master and personal CRM

Label: source.
- `res.partner` (`_description = 'Contact'`) is defined once in core `base` (`odoo/addons/base/models/res_partner.py`) and used as the single contact/company/vendor/customer master across all apps; `contacts/models/res_partner.py` only `_inherit`s it to add a menu entry — it does not define a new model.
- No evidence in this repo of a separate "personal contacts" or private-relationship-management model distinct from `res.partner`; CRM's `crm.lead` has its own `res_partner.py` extension (`crm/models/res_partner.py`, present in the manifest's model list) but this again extends the shared partner model rather than creating a parallel one. NOT FOUND: any personal/private CRM object separate from `res.partner`/`crm.lead`.

---

## ERPNext (`frappe/erpnext` @ `version-15`) and the Frappe framework

### Q1. Top-level modules/apps and installability

Label: source.
- ERPNext ships as **one single installable app** (`erpnext`), not a set of independently installable apps. `erpnext/modules.txt` (its logical module list) contains: `Accounts, CRM, Buying, Projects, Selling, Setup, Manufacturing, Stock, Support, Utilities, Assets, Portal, Maintenance, Regional, ERPNext Integrations, Quality Management, Communication, Telephony, Bulk Transaction, Subcontracting, EDI`.
- `pyproject.toml`: `[tool.bench.frappe-dependencies] frappe = ">=15.111.0,<16.0.0"` — ERPNext's only declared app dependency is the `frappe` framework itself; there is no `required_apps` splitting CRM/Selling/Accounts into separate installable apps. Each DocType instead carries a `"module"` string used for UI/permission grouping, not for independent installability.
- Contrast with the standalone apps built on the same framework:
  - `frappe/crm` (Frappe CRM) `pyproject.toml`: `dependencies = ["twilio==8.5.0", "requests>=2.28.0", "tldextract>=5.0.0", ...]` and `crm/hooks.py`: `# required_apps = []` (commented but present, i.e. no other Frappe app is mandatory) — Frappe CRM installs on bare Frappe, independent of ERPNext.
  - `frappe/hrms` (Frappe HR) `hrms/hooks.py:7`: `required_apps = ["frappe/erpnext"]` — Frappe HR **requires ERPNext** to be installed (it reuses ERPNext's Employee/Company/Accounts records).
  - `frappe/helpdesk` `helpdesk/hooks.py:9`: `required_apps = ["telephony"]` and `pyproject.toml`: `[tool.bench.frappe-dependencies] frappe = ">=16.0.0-dev,<18.0.0"`, `telephony = ">=0.0.1,<1.0.0"` — Helpdesk requires the `telephony` app but **not** ERPNext or CRM.

### Q2. Records owned per module (`"module"` field in DocType JSON)

Label: source, from `grep '"module"'` in each doctype JSON.
- Selling: `Sales Order` (`erpnext/selling/doctype/sales_order/sales_order.json`), `Quotation` (`.../quotation/quotation.json:1113`), `Customer` (`.../customer/customer.json:623`).
- CRM (inside ERPNext itself): `Lead` (`erpnext/crm/doctype/lead/lead.json:522`), `Opportunity` (`.../opportunity/opportunity.json:630`), `Contract` (`.../contract/contract.json:262`).
- Accounts: `Sales Invoice` (`erpnext/accounts/doctype/sales_invoice/sales_invoice.json:2204`), `Journal Entry` (`.../journal_entry/journal_entry.json:571`), `Bank Transaction` (`.../bank_transaction/bank_transaction.json:266`), `POS Invoice` (`.../pos_invoice/pos_invoice.json:1577`), `Subscription` (`.../subscription/subscription.json:272`).
- Buying: `Supplier` (`erpnext/buying/doctype/supplier/supplier.json:496`).
- Projects: `Project` (`erpnext/projects/doctype/project/project.json:471`), `Task` (`.../task/task.json:409`), `Timesheet` (`.../timesheet/timesheet.json:315`).
- Assets: `Asset` (`erpnext/assets/doctype/asset/asset.json:602`).
- Core (framework, not ERPNext): `Contact` (`frappe/contacts/doctype/contact/contact.json:262`, module `Contacts`), `File` (`frappe/core/doctype/file/file.json:196`, module `Core`).

### Q3. Sales: quotes, orders, customer invoices, channels

Label: source.
- Quotation and Sales Order are both `module: Selling` (Quotation has a link field `opportunity` — `quotation.json:134/928` — pointing at the CRM Opportunity). No separate CRM-owned order/quote object exists.
- Sales Invoice is `module: Accounts` — `Sales Invoice Item` child rows carry a `sales_order` link field (`erpnext/accounts/doctype/sales_invoice_item/sales_invoice_item.json:700`: `"fieldname": "sales_order"`), which is optional per line — a Sales Invoice can be created with or without a linked Sales Order, i.e. Accounting can issue an invoice with no order behind it.
- Channels:
  - **CRM Opportunity → Quotation**: `Quotation.opportunity` is a direct link field inside the Selling module's own doctype; Opportunity itself (module `CRM`) does not own a quotation model — Selling owns Quotation and merely references back to the Opportunity.
  - **POS**: `POS Invoice` (module `Accounts`) is a distinct doctype from `Sales Invoice`, used for point-of-sale transactions; it lives in Accounts, not Selling.
  - **e-commerce**: **NOT FOUND** inside `erpnext` — no `e_commerce`/`webshop` directory exists under `erpnext/` in this repo (checked via `git ls-tree`); ERPNext's storefront ("Webshop") ships as a separate Frappe app (`frappe/webshop`), outside the scope of this pass — confirmed only as an absence here, not verified in the webshop repo itself.
  - **Subscriptions**: `Subscription` doctype, module `Accounts` — subscriptions are an Accounts-owned recurring-billing object, not Selling or CRM.
  - **Sale of a fixed asset**: `Asset` doctype lives in module `Assets` (`erpnext/assets/doctype/asset/asset.json:602`); disposal/sale of an asset in ERPNext is handled through Asset-module logic feeding a Sales Invoice — the Asset record itself, not a Sales Order, is the source object. (Exact disposal-to-invoice code path not traced in this pass; doctype module ownership only. Label: inferred for the disposal flow, source for the module field.)

### Q4. CRM: what it owns, does it create sales/finance documents

Two distinct "CRM"s must be separated:

**(a) ERPNext's built-in CRM module** (module string `CRM` inside the single `erpnext` app): owns `Lead`, `Opportunity`, `Contract` (source, Q2 above). Because ERPNext is one app with one database, "hand-off" here is just following the `opportunity` link field on `Quotation` — there is no cross-app boundary, so Lead/Opportunity data and Sales Order/Invoice data share the same app and can be joined directly. Label: inferred from the shared-app structure in Q1 plus the link field in Q3.

**(b) Frappe CRM (`frappe/crm`), the standalone product**: owns its own doctypes under `crm/fcrm/doctype/`: `crm_lead`, `crm_deal` (its opportunity-equivalent), `crm_organization`, `crm_contacts`, `crm_task`, `crm_product`, `crm_service_level_agreement`, etc. (full listing obtained via `ls crm/fcrm/doctype`). A `grep` across all `crm/fcrm/doctype/*/*.json` for `quotation|invoice|sales_order` returned **no matches** — Frappe CRM's own schema has no quotation/invoice fields. Its integration point is `erpnext_crm_settings` (`crm/fcrm/doctype/erpnext_crm_settings/erpnext_crm_settings.json`), whose fields are `api_key`, `api_secret`, `erpnext_site_url`, `erpnext_company`, `enabled`, `sync_products`, `create_customer_on_status_change`, `deal_status` — i.e. Frappe CRM talks to a *separate* ERPNext site over an API/site-URL integration and can optionally push a Customer record on deal-status change; it does not create Sales Orders/Invoices itself and does not share a database with ERPNext by default.

### Q5. Projects: does it own records or is it a dimension/view?

Label: source.
- `Project`, `Task`, and `Timesheet` are all real doctypes with module `Projects` (Q2), each with their own tables — Projects genuinely owns these records (not merely a view).
- `Sales Invoice Item.sales_order` and other links show billing flows through Accounts/Selling doctypes rather than through a project-owned billing record; no "Project Invoice" doctype was found in the sparse-checked project doctype set (`erpnext/projects/doctype/*`) — project billing in ERPNext is expressed via Sales Order/Timesheet references rather than a Projects-owned invoice model. Label: inferred from absence in the checked set (not exhaustive of every doctype under `erpnext/projects`).

### Q6. Accounting: what it owns

Label: source. `Sales Invoice`, `Purchase Invoice`, `Journal Entry`, `Bank Transaction`, `Payment Entry`, `POS Invoice`, `Subscription`, and `Asset Capitalization` doctypes are all module `Accounts` (per Q2/Q3 grep results). Sales Invoice carries an optional `sales_order` reference on its line items but is itself an Accounts-module doctype, independent of whether Selling created a Sales Order first — structurally analogous to Odoo's `account.move` being invoked from `sale.order` but owned by `account`.

### Q7. Documents/DMS module

Label: source.
- No ERPNext-specific "Documents" module was found among `erpnext/modules.txt` entries (Accounts, CRM, Buying, Projects, Selling, Setup, Manufacturing, Stock, Support, Utilities, Assets, Portal, Maintenance, Regional, ERPNext Integrations, Quality Management, Communication, Telephony, Bulk Transaction, Subcontracting, EDI — no "Documents").
- File attachment is handled generically by the Frappe framework's `File` doctype (module `Core`, not part of ERPNext): `frappe/core/doctype/file/file.json` has fields `attached_to_doctype` (line 128 area) and `attached_to_name` — the same polymorphic-link pattern as Odoo's `ir.attachment`. Every ERPNext/CRM/HR/Helpdesk doctype attaches files through this one shared `File` doctype; there is no document-module ownership layer above it.

### Q8. Contacts: shared master and personal CRM

Label: source.
- `Contact` is defined once in the Frappe framework (`frappe/contacts/doctype/contact/contact.json`, module `Contacts`), shared by every app built on Frappe (ERPNext, Frappe CRM, Frappe HR, Helpdesk).
- `Contact` links to business parties via a **Dynamic Link** child table (`contact.json:147`: `"options": "Dynamic Link"`) rather than a hard foreign key to one specific doctype — this is how one Contact can be linked to a `Customer`, `Supplier`, `Lead`, or any other party doctype (Customer is `module: Selling`, `customer.json:623`; Supplier is `module: Buying`, `supplier.json:496`).
- No personal/private relationship-management object distinct from `Contact` was found in the checked scope. Frappe CRM has its own `crm_contacts` doctype (`crm/fcrm/doctype/crm_contacts`) which — per the CRM's use of `erpnext_crm_settings` for cross-app sync (Q4) — appears to be Frappe CRM's local copy/extension of contact data rather than a shared master with ERPNext by default; this local-vs-shared distinction was not traced further at the field level in this pass (label: inferred from the API-integration pattern found in Q4, not directly confirmed by reading `crm_contacts.json` fields).

---

## Summary table

| App | Top-level modules/apps (installable alone) | Sales owner & channels | CRM role | Projects role | Documents module | Shared contacts |
|---|---|---|---|---|---|---|
| Odoo 18 | `sale` (needs `account_payment`→`account`), `crm` (standalone, no `sale`/`account` dep), `project` (standalone, needs `analytic`), `account` (standalone), `point_of_sale` (needs `stock_account`→`account`, not `sale`), `website_sale` (needs `sale`); bridge `sale_crm` (`auto_install` when both present) | `sale` owns `sale.order`/quotation; invoice is `account.move` (`out_invoice`) owned by `account`, created via `sale`'s `_create_invoices`. Channels: CRM lead/opportunity → `sale.order` only via `sale_crm` bridge; POS → own `pos.order` model (not `sale.order`), invoices directly to `account.move`; eCommerce (`website_sale`) → extends `sale.order` directly (depends on `sale`); Subscriptions/Assets → Enterprise-only, NOT FOUND in Community source | Owns `crm.lead`/`crm.team`/stages only; zero references to `sale.order` or `account.move` in its own code; hands off to Sales only through the separate `sale_crm` addon | Owns `project.project`/`task`/`milestone`/`update` as real records, but financial rollups (profitability, billing) are computed by reading `account.analytic.line`/`account.move` via the shared analytic account and via bridge addons `sale_project`/`sale_timesheet` — a dimension/view over Sales+Accounting money data layered on top of real task records | Enterprise-only `documents` app, NOT FOUND in Community; Community attachments use generic `ir.attachment` (`res_model`/`res_id`) from core `base` | Single `res.partner` model in core `base`, reused (not redefined) by every app via `_inherit`; no separate personal-CRM object found |
| ERPNext (single app) | One app `erpnext` (only dependency: `frappe`); internal "modules" (`Accounts`, `CRM`, `Selling`, `Projects`, `Assets`, etc.) are UI/permission groupings, not separately installable apps | `Selling` owns `Sales Order`/`Quotation`; `Accounts` owns `Sales Invoice`/`POS Invoice`/`Journal Entry`/`Subscription`, with an optional `sales_order` link on invoice line items (invoice can exist with no order). e-commerce (Webshop) NOT FOUND inside `erpnext` — ships as a separate Frappe app; Asset disposal flows from the `Assets`-module `Asset` doctype | Built-in `CRM` module (`Lead`,`Opportunity`,`Contract`) shares the same app/database as Selling/Accounts, so `Quotation.opportunity` link joins them directly with no integration layer needed | `Project`/`Task`/`Timesheet` are real Projects-module doctypes; no project-owned invoice doctype found — billing flows through Selling/Accounts doctypes referencing Timesheet/Sales Order | No ERPNext-specific documents module (absent from `erpnext/modules.txt`); generic `File` doctype (framework `Core`, `attached_to_doctype`/`attached_to_name`) used everywhere | `Contact` (framework `Contacts` module) linked to `Customer`/`Supplier`/`Lead` via a `Dynamic Link` child table — one shared master across all Frappe apps |
| Frappe CRM (`frappe/crm`) | Standalone app on bare Frappe (`required_apps` effectively empty); does not require ERPNext | Owns no Sales Order/Invoice fields at all (grep confirmed none in its doctypes); integrates with a separate ERPNext site via `erpnext_crm_settings` (API key/site URL), optionally pushing a Customer on deal-status change | Owns `crm_lead`, `crm_deal`, `crm_organization`, `crm_contacts`, `crm_task`, etc.; does not create Sales/Finance documents itself — hands off via API integration, not shared DB | `crm_task` exists but is CRM-scoped (activity/follow-up task), not a Projects-module doctype | NOT FOUND (own documents module); relies on framework `File` doctype like ERPNext | Has its own `crm_contacts` doctype; relationship to the framework-shared `Contact`/ERPNext `Customer` is via the API sync layer, not a shared table by default (inferred) |
| Frappe HR (`hrms`) | `required_apps = ["frappe/erpnext"]` — cannot be installed standalone; depends on ERPNext | Not a sales module (out of scope for sales ownership); reuses ERPNext's Employee/Company/Accounts records because it requires ERPNext | N/A | N/A | NOT FOUND (own module); relies on framework `File` | Reuses ERPNext's shared `Contact`/`Customer`/`Employee` records via the `required_apps` dependency (inferred from the hard dependency) |
| Frappe Helpdesk (`helpdesk`) | `required_apps = ["telephony"]` — depends on the `telephony` app, not on ERPNext or CRM | Not a sales module | N/A (ticketing, not lead/opportunity management) | N/A | NOT FOUND (own module); relies on framework `File` | Relies on framework-shared `Contact` (inferred; not directly traced at field level in this pass) |

## Finding most relevant to the owner's question

The strongest, most directly falsifiable piece of evidence is the **`sale_crm` bridge addon** in Odoo: it is a *separate, optional* module (`depends: ['sale', 'crm']`, `auto_install: True`) that adds `sale.order.opportunity_id` and `crm.lead.order_ids` — proof that Odoo's core CRM module (`crm`) has **zero code-level knowledge of Sales** (`grep -rl "sale.order\|sale_order" crm/` returned nothing), and Sales has zero required dependency on CRM (`sale/__manifest__.py` depends only on `sales_team`, `account_payment`, `utm`). The same separation-by-integration pattern repeats in Frappe CRM, which talks to ERPNext only through an API/site-URL settings doctype (`erpnext_crm_settings`), not a shared table. In both ecosystems, **Sales/quoting/invoicing records are owned by the finance-adjacent module (Odoo's `sale`+`account`, ERPNext's `Selling`+`Accounts`), while CRM is purely a lead/opportunity-qualification layer that hands off through an explicit, separate integration point** — it is never CRM's own model that becomes the order or the invoice. POS (own `pos.order` model, invoices directly) and eCommerce (extends `sale.order` directly, depends on `sale`) show two different landing patterns for non-CRM channels: POS bypasses the Sales-order model entirely and goes straight to the ledger; eCommerce reuses the Sales-order model directly. Projects, in both products, owns real task/milestone/timesheet records but is architecturally a **rollup/dimension consumer of Accounting's analytic/ledger data for anything money-related** (Odoo's analytic account; ERPNext's Sales Order/Invoice links from Timesheet), not itself a system of record for sales or invoices — supporting a "Projects is closer to a dashboard over Sales+Accounting" reading for the billing/profitability slice specifically, while still owning the task-management slice outright.
