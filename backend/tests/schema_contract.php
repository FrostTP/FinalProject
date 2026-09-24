<?php
// Read expectations from the user's original DD, not from implementation SQL.
function verify_schema_contract(PDO $pdo): int {
    $source=file_get_contents(__DIR__.'/../../docs/approved-data-dictionary.txt');
    $names=require __DIR__.'/../timeguard_api/config/table_names.php';
    $tables=[];$table=null;
    foreach(preg_split('/\r?\n/',$source) as $line){
        if(preg_match('/^\d+\. (E|A|H|S|D|CFG|F|G|EA|OS|AT) - /',$line,$m)){$table=$names[$m[1]];$tables[$table]=[];continue;}
        if($table && preg_match('/^(\w+) (varchar\(\d+\)|decimal\(\d+,\d+\)|datetime|date|time|text|boolean)(?:\s|$)(.*)$/',$line,$m)){
            $tables[$table][$m[1]]=['type'=>$m[2]==='boolean'?'tinyint(1)':$m[2],'pk'=>str_contains($m[3],'PK')];
            if(preg_match('/FK -> (\w+)\.(\w+)/',$m[3],$fk)){$tables[$table][$m[1]]['fk']=$names[$fk[1]].'.'.$fk[2];}
        }
    }
    if(count($tables)!==11){throw new RuntimeException('Could not parse the approved DD');}
    $count=0;
    foreach($tables as $table=>$expected){
        $rows=$pdo->query("SHOW COLUMNS FROM `$table`")->fetchAll(PDO::FETCH_ASSOC);$actual=[];foreach($rows as $row){$actual[$row['Field']]=$row;}
        if(array_keys($actual)!==array_keys($expected)){throw new RuntimeException("$table columns do not match original DD: ".json_encode(array_keys($expected)));}
        $s=$pdo->prepare('SELECT COLUMN_NAME,REFERENCED_TABLE_NAME,REFERENCED_COLUMN_NAME FROM information_schema.KEY_COLUMN_USAGE WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=? AND REFERENCED_TABLE_NAME IS NOT NULL');$s->execute([$table]);$fks=[];foreach($s as $fk){$fks[$fk['COLUMN_NAME']]=strtolower($fk['REFERENCED_TABLE_NAME']).'.'.$fk['REFERENCED_COLUMN_NAME'];}
        foreach($expected as $column=>$spec){
            if(strtolower($actual[$column]['Type'])!==$spec['type']){throw new RuntimeException("$table.$column type mismatch");}
            if(($actual[$column]['Key']==='PRI')!==$spec['pk']){throw new RuntimeException("$table.$column primary key mismatch");}
            if(($fks[$column]??null)!==($spec['fk']??null)){throw new RuntimeException("$table.$column foreign key mismatch");}
            $count++;
        }
    }
    echo "PASS original DD: $count columns, their types, primary keys and foreign keys across 11 tables\n";return $count;
}
