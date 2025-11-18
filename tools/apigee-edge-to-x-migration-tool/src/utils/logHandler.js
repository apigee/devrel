/**
 * Copyright 2025 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import libsql from 'libsql';
import Table from 'cli-table3';
import wrapAnsi from 'wrap-ansi';
import getDataDirectory from './getDataDirectory.js';

class Logger {
  static _instance = null;
  _db = null;
  _batchSize = 200; // Set the batch size for pagination

  constructor() {
    if (Logger._instance) {
      return Logger._instance;
    }

    const dataDirectory = getDataDirectory(process.env.source_gateway_org);
    const dbPath = `${dataDirectory}/${process.env.destination_gateway_org}.db`;

    try {
      this._db = new libsql(dbPath);
      // console.log(`Database created or opened at: ${dbPath}`);
      this._initializeTables();
    } catch (error) {
      console.error('Failed to create or open database:', error);
    }

    Logger._instance = this;
  }

  _initializeTables() {
    this._initializeLogTable();
    this._initializeDeviationsTable();
    this._initializeEntitiesTable();
  }

  _initializeLogTable() {
    try {
      this._db.exec("CREATE TABLE IF NOT EXISTS log (id INTEGER PRIMARY KEY AUTOINCREMENT, type TEXT NOT NULL, timestamp INTEGER NOT NULL, key TEXT NOT NULL, message TEXT NOT NULL, metadata TEXT)");
      // console.log('Log table initialized successfully.');
    } catch (error) {
      console.error('Failed to initialize log table:', error);
    }
  }

  _initializeDeviationsTable() {
    try {
      this._db.exec("CREATE TABLE IF NOT EXISTS deviations (entity_type TEXT NOT NULL, entity_name TEXT NOT NULL, source_data TEXT, target_data TEXT, deviations TEXT, merged_data TEXT, migrationAttempted TEXT NOT NULL, PRIMARY KEY (entity_type, entity_name, migrationAttempted))");
      // console.log('Deviations table initialized successfully.');
    } catch (error) {
      console.error('Failed to initialize deviations table:', error);
    }
  }

  _initializeEntitiesTable() {
    try {
      this._db.exec("CREATE TABLE IF NOT EXISTS entities (entity_type TEXT NOT NULL, entity_name TEXT NOT NULL, migration_state TEXT, migration_attempted TEXT, cause TEXT, PRIMARY KEY (entity_type, entity_name))");
      // console.log('MigrationStatus table initialized successfully.');
    } catch (error) {
      console.error('Failed to initialize migrations table:', error);
    }
  }

  static getInstance() {
    if (!Logger._instance) {
      Logger._instance = new Logger();
    }
    return Logger._instance;
  }

  // Method for migrationStatus
  createStatusEntry(record) {
    try {
      const { entityType, entityName, migrationState, migrationAttempted, cause } = record;
      this._db.prepare(`INSERT INTO entities (entity_type, entity_name, migration_state, migration_attempted, cause)
      VALUES (?, ?, ?, ?, ?) ON CONFLICT(entity_type, entity_name) DO UPDATE SET migration_state=?, migration_attempted=?, cause=?`).run(
        entityType, entityName, migrationState, migrationAttempted, cause, migrationState, migrationAttempted, cause
      );
    } catch (err) {
      console.error('Error creating migration entry:', err);
    }
  }

  // Method for deviations
  createDeviationsEntry(record) {
    try {
      const { entityType, entityName, source_data, target_data, deviations, merged_data, migrationAttempted } = record;
      this._db.prepare(`INSERT INTO deviations (entity_type, entity_name, source_data, target_data, deviations, merged_data, migrationAttempted)
        VALUES (?, ?, ?, ?, ?, ?, ?) ON CONFLICT(entity_type, entity_name, migrationAttempted) DO UPDATE SET source_data=?, target_data=?, deviations=?, merged_data=?`).run(
        entityType, entityName,
        JSON.stringify(source_data), JSON.stringify(target_data), JSON.stringify(deviations), JSON.stringify(merged_data), migrationAttempted,
        JSON.stringify(source_data), JSON.stringify(target_data), JSON.stringify(deviations), JSON.stringify(merged_data)
      );
    } catch (err) {
      console.error('Error creating migration entry:', err);
    }
  }

  // Method for accessLog
  createLogEntry(type, key, message, metadata = '') {
    if (!message) return;

    try {
      const results = this._db.prepare('INSERT INTO log (type, timestamp, key, message, metadata) VALUES (?, ?, ?, ?, ?)').run(
        type, Date.now(), key, message, typeof metadata === 'string' ? metadata : JSON.stringify(metadata)
      );
      const displayLogLevel = process.env.TERMINAL_LOG_LVL !== undefined ? process.env.TERMINAL_LOG_LVL.toUpperCase() : type.toUpperCase();
      if (displayLogLevel === type.toUpperCase()) {
        console.log(`[${type.toUpperCase()} ${results.lastInsertRowid}] ${message}.`, 'See log database for more info.');
      }
    } catch (err) {
      console.error('Error creating log entry:', err);
    }
  }

  // Logger methods as class methods
  log(key, message, metadata) {
    this.createLogEntry('log', key, message, metadata);
  }

  warning(key, message, metadata) {
    this.createLogEntry('warning', key, message, metadata);
  }

  error(key, message, metadata) {
    this.createLogEntry('error', key, message, metadata);
  }

  viewLogs(type = null) {
    try {
      let query = `SELECT 
      *,
      CASE 
          WHEN metadata LIKE '%Buffer%' THEN 'Bundle logged as buffer in DB.'
          ELSE metadata 
      END AS metadata
      FROM 
        log`;
      const params = [];

      if (type) {
        query += ` AND type = ?`;
        // query += ` WHERE type = ?`;
        params.push(type);
      }

      let offset = 0;
      let hasMoreRecords = true;

      while (hasMoreRecords) {
        const paginatedQuery = `${query} ORDER BY "id" desc LIMIT ${this._batchSize} OFFSET ${offset}`;
        const logs = this._db.prepare(paginatedQuery).all(...params);

        if (logs.length > 0) {
          this.printLogTable(logs, this._batchSize);
          offset += this._batchSize;
        } else {
          hasMoreRecords = false;
        }
      }

      process.exit(0); // Exit the tool after printing logs

    } catch (err) {
      console.error('Error fetching logs:', err);
    }
  }

  viewDeviations(entityType = null) {
    try {
      let query = 'SELECT * FROM deviations';
      const params = [];

      if (entityType) {
        query += ' WHERE entity_type=?';
        params.push(entityType);
      }

      const deviations = this._db.prepare(query).all(...params);
      this.printLogTable(deviations);

      process.exit(0); // Exit the tool after printing logs

    } catch (err) {
      console.error('Error fetching deviations:', err);
    }
  }

  async viewMigrationStatus(entityType = null, migrationState = null) {
    try {
      let query = 'SELECT * FROM entities';
      const conditions = [];
      const params = [];

      if (entityType) {
        conditions.push('entity_type=?');
        params.push(entityType);
      }

      if (migrationState) {
        conditions.push('migration_state=?');
        params.push(migrationState);
      }

      if (conditions.length > 0) {
        query += ' WHERE ' + conditions.join(' AND ');
      }

      const records = this._db.prepare(query).all(...params);

      this.printLogTable(records);

      process.exit(0); // Exit the tool after printing logs

    } catch (err) {
      console.error('Error fetching migration status records:', err);
    }
  }

  async viewMigrationSummary(entityType = null) {
    try {
      const query = `
        SELECT
          entity_type AS entityType,
          COUNT(*) AS total,
          SUM(CASE WHEN migration_state = 'Migrated' THEN 1 ELSE 0 END) AS migrated,
          SUM(CASE WHEN migration_state = 'Skipped' THEN 1 ELSE 0 END) AS skipped,
          SUM(CASE WHEN migration_state = 'Failed' THEN 1 ELSE 0 END) AS failed
        FROM entities
        ${entityType ? 'WHERE entity_type = ?' : ''}
        GROUP BY entity_type
      `;
      const params = entityType ? [entityType] : [];

      const summary = this._db.prepare(query).all(...params);

      if (summary.length > 0) {
        this.printSummaryTable(summary);
      } else {
        console.log('No summary data found.');
      }

      process.exit(0); // Exit the tool after printing logs

    } catch (err) {
      console.error('Error fetching migration summary:', err);
    }
  }

  printSummaryTable(summaryData) {
    if (!summaryData.length) {
      console.log('No summary data found.');
      return;
    }

    const headers = ['ENTITY TYPE', 'TOTAL RECORDS', 'MIGRATED', 'SKIPPED', 'FAILED'];

    const table = new Table({
      head: headers,
      colWidths: [20, 15, 15, 15, 15], // Adjust column widths as needed
      wordWrap: true
    });

    summaryData.forEach(data => {
      table.push([
        data.entityType,
        data.total,
        data.migrated,
        data.skipped,
        data.failed
      ]);
    });

    console.log(table.toString());
  }

  printLogTable(records) {
    if (!records.length) {
      console.log('No records found.');
      return;
    }

    const headers = ['INDEX', ...Object.keys(records[0]).map(header => header.toUpperCase())];
    const availableWidth = Math.max(200, process.stdout.columns || 200);

    // Calculate appropriate column widths
    const colWidths = headers.map(header => {
      const maxContentWidth = Math.max(
        header.length,
        ...records.map((record, index) => (header === 'INDEX' ? index.toString().length : (record[header.toLowerCase()] || '').toString().length))
      );
      return Math.min(maxContentWidth + 2, Math.floor(availableWidth / headers.length));
    });

    const table = new Table({
      head: headers,
      colWidths,
      wordWrap: true
    });

    records.forEach((record, index) => {
      const row = [index, ...headers.slice(1).map(header => wrapAnsi((record[header.toLowerCase()] || '').toString(), colWidths[headers.indexOf(header)], { hard: true }))];
      table.push(row);
    });
    console.log(table.toString());
  }

}

export default Logger;