-- Warehouse schema and reference data. Inventory starts empty.

CREATE TABLE warehouses (
    code text PRIMARY KEY,
    name text NOT NULL
);

CREATE TABLE products (
    sku  text PRIMARY KEY,
    name text NOT NULL
);

CREATE TABLE shipments (
    id             text PRIMARY KEY,
    warehouse_code text NOT NULL REFERENCES warehouses (code),
    received_on    date NOT NULL
);

CREATE TABLE shipment_lines (
    shipment_id text NOT NULL REFERENCES shipments (id),
    sku         text NOT NULL REFERENCES products (sku),
    quantity    integer NOT NULL CHECK (quantity > 0),
    PRIMARY KEY (shipment_id, sku)
);

CREATE TABLE inventory (
    warehouse_code  text NOT NULL REFERENCES warehouses (code),
    sku             text NOT NULL REFERENCES products (sku),
    on_hand         integer NOT NULL DEFAULT 0,
    last_receipt_on date,
    PRIMARY KEY (warehouse_code, sku)
);

INSERT INTO warehouses (code, name) VALUES
    ('AMS', 'Amsterdam'),
    ('LIS', 'Lisbon');

INSERT INTO products (sku, name) VALUES
    ('BOLT-6',  'Hex bolt 6mm'),
    ('NUT-6',   'Hex nut 6mm'),
    ('WASH-6',  'Washer 6mm');
