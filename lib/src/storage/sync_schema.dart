// Migration déterministe pour le seed : aucun identifiant d’appareil sans suivi.
const _device =
    "INSERT OR IGNORE INTO sync_device(slot,device_id) VALUES(1,'d_'||lower(hex(randomblob(16))));";
const _actor = '(SELECT device_id FROM sync_device WHERE slot=1)';
const _active =
    '(SELECT COALESCE((SELECT suppress FROM sync_device WHERE slot=1),0))=0';
const syncFieldExpressions = {
  'favorite': "CASE WHEN %r.is_favorite=1 THEN 'true' ELSE 'false' END",
  'status': "json_object('completed_at',%r.completed_at,'listening_status',%r.listening_status)",
  'position': "json_object('duration_ms',NULLIF(%r.duration_ms,0),'last_played_at',%r.last_played_at,'position_ms',%r.position_ms)",
};
const _reset = {
  'favorite': "'false'",
  'status': "json_object('completed_at',NULL,'listening_status','NON_ECOUTE')",
  'position':
      "json_object('duration_ms',NULL,'last_played_at',NULL,'position_ms',0)",
};
String _write(String field, String row, String value, {bool initial = false}) =>
    '''
INSERT INTO sync_fields(episode_id,field,value_json,clock_json)
VALUES($row.episode_id,'$field',$value,${initial ? "CASE WHEN ($value)=(${_reset[field]}) THEN '{}' ELSE json_object($_actor,1) END" : 'json_object($_actor,1)'})
ON CONFLICT(episode_id,field) DO UPDATE SET value_json=excluded.value_json,
clock_json=json_set(sync_fields.clock_json,'\$."'||$_actor||'"',
 COALESCE(json_extract(sync_fields.clock_json,'\$."'||$_actor||'"'),0)+1)
${initial ? 'WHERE sync_fields.value_json IS NOT excluded.value_json' : ''};
UPDATE sync_device SET revision=revision+1 WHERE slot=1;
''';

String get schemaV7 {
  final sql = StringBuffer('''
CREATE TABLE sync_device(slot INTEGER PRIMARY KEY CHECK(slot=1),device_id TEXT NOT NULL UNIQUE,
 suppress INTEGER NOT NULL DEFAULT 0 CHECK(suppress IN(0,1)),revision INTEGER NOT NULL DEFAULT 0);
CREATE TABLE sync_fields(episode_id TEXT NOT NULL REFERENCES episodes(id),field TEXT NOT NULL CHECK(field IN('favorite','status','position')),
 value_json TEXT NOT NULL,clock_json TEXT NOT NULL,PRIMARY KEY(episode_id,field));
CREATE TABLE sync_imports(export_id TEXT PRIMARY KEY,digest TEXT NOT NULL,source_device_id TEXT NOT NULL,
 imported_at TEXT NOT NULL,summary_json TEXT NOT NULL);
INSERT INTO sync_device(slot,device_id)
 SELECT 1,'d_'||lower(hex(randomblob(16))) WHERE EXISTS(SELECT 1 FROM user_episode_state);
''');
  for (final field in syncFieldExpressions.keys) {
    final expression = syncFieldExpressions[field]!;
    sql.write('''
INSERT INTO sync_fields SELECT episode_id,'$field',${expression.replaceAll('%r.', '')},json_object($_actor,1) FROM user_episode_state;
CREATE TRIGGER sync_${field}_insert AFTER INSERT ON user_episode_state WHEN $_active BEGIN
$_device
${_write(field, 'NEW', expression.replaceAll('%r', 'NEW'), initial: true)}
END;
CREATE TRIGGER sync_${field}_update AFTER UPDATE ON user_episode_state
 WHEN $_active AND (${expression.replaceAll('%r', 'NEW')}) IS NOT (${expression.replaceAll('%r', 'OLD')}) BEGIN
$_device
${_write(field, 'NEW', expression.replaceAll('%r', 'NEW'))}
END;
CREATE TRIGGER sync_${field}_delete AFTER DELETE ON user_episode_state WHEN $_active BEGIN
$_device
${_write(field, 'OLD', _reset[field]!)}
END;
''');
  }
  return sql.toString();
}
