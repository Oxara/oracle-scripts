-- Sequence bilgilerini tutmak üzere SEQUENEC tablosu oluşturuyoruz.
-- Burada mevcut tabloların PrimaryKey ve Sequence ilişkileri üzerinden analiz yapacağız.
-- Şema, tablo, primary Key ve sequence bilgileri üzerinden kurulan ilişkiler ile
-- Tablodaki sequence numarası ve ayarları hakkında bilgi sahibi olup, dinamik sorgular ile
-- tablodaki max Id'yi alıp, karşılaştırmalar yapıp. Olması gereken güncel sequence bilgisini
-- atayacağız.
BEGIN
    DECLARE
        TABLE_COUNT NUMBER;
    BEGIN
        -- Tablonun var olup olmadığını kontrol edin
        SELECT COUNT(*) INTO TABLE_COUNT 
        FROM ALL_TABLES 
        WHERE TABLE_NAME = 'SEQUENCE_INFO' AND OWNER = USER;
        
       -- Eğer tablo varsa, tabloyu temizle; yoksa oluştur
        IF TABLE_COUNT > 0 THEN EXECUTE IMMEDIATE 'TRUNCATE TABLE SEQUENCE_INFO';
        ELSE
            EXECUTE IMMEDIATE '
            CREATE GLOBAL TEMPORARY TABLE SEQUENCE_INFO (
                Schema VARCHAR2(35),
                Table_Name VARCHAR2(50),
                Column_Name VARCHAR2(50),
                Sequence_Name VARCHAR2(50),
                Generation_Type VARCHAR2(50),
                Min_Sequence NUMBER,
                Max_Sequence NUMBER,
                Increment_By NUMBER,
                Last_Sequence_Number NUMBER,
                Table_Row_Count NUMBER,
                Max_Id NUMBER,
                SeqUpdateNeeded NUMBER(1),
                Expected_Seq_Id NUMBER
            ) ON COMMIT PRESERVE ROWS';
        END IF;
    END;
END;
/

-- Sorgu sonucunu SEQUENCE_INFO tablosuna yaz
INSERT INTO SEQUENCE_INFO
SELECT 
    pk.OWNER AS Schema,
    pk.TABLE_NAME AS Table_Name,
    pk.COLUMN_NAME AS Column_Name,
    pk.SEQUENCE_NAME AS Sequence_Name,
    pk.GENERATION_TYPE AS Generation_Type,
    seq.MIN_VALUE AS Min_Sequence,
    seq.MAX_VALUE AS Max_Sequence,
    seq.INCREMENT_BY AS Increment_By,
    seq.LAST_NUMBER AS Last_Sequence_Number,
    tab.NUM_ROWS AS Table_Row_Count,
    NULL AS Max_Id,
    NULL AS SeqUpdateNeeded,
    NULL AS Expected_Seq_Id
FROM ALL_TAB_IDENTITY_COLS pk
LEFT JOIN ALL_SEQUENCES seq ON seq.SEQUENCE_NAME = pk.SEQUENCE_NAME
LEFT JOIN ALL_TABLES tab ON tab.OWNER = pk.OWNER AND tab.TABLE_NAME = pk.TABLE_NAME
WHERE pk.COLUMN_NAME = 'Id' || pk.TABLE_NAME;
/


DECLARE
    CURSOR sequence_cursor IS SELECT * FROM SEQUENCE_INFO;
    sequence_row SEQUENCE_INFO%ROWTYPE;
    max_id_value NUMBER;
    is_seq_update_needed NUMBER(1);
    expected_seq_value NUMBER;
    dynamic_sql VARCHAR2(1000);
BEGIN
    OPEN sequence_cursor;
    LOOP
        FETCH sequence_cursor INTO sequence_row;
        EXIT WHEN sequence_cursor%NOTFOUND;

        -- Dinamik SQL ile maksimum ID'yi al
        dynamic_sql := 'SELECT MAX("' || sequence_row.Column_Name || '") FROM "' || sequence_row.Schema || '"."' || sequence_row.Table_Name || '"';
        EXECUTE IMMEDIATE dynamic_sql INTO max_id_value;
       
        max_id_value := COALESCE(max_id_value, 0);
        
        -- Eğer maksimum ID, güncel sequence numarasından büyükse sequence'in güncellenmesi gerekiyor
        IF max_id_value > sequence_row.Last_Sequence_Number THEN
            is_seq_update_needed := 1;
            expected_seq_value := max_id_value + 1;
        ELSE
            is_seq_update_needed := 0;
            expected_seq_value := sequence_row.Last_Sequence_Number;
        END IF;

       -- SEQUENCE_INFO tablosunu bu bilgilerle tekrar güncelle.
        UPDATE sequence_info
        SET Max_Id = max_id_value,
            SeqUpdateNeeded = is_seq_update_needed,
            Expected_Seq_Id = expected_seq_value
        WHERE Schema = sequence_row.Schema
          AND Table_Name = sequence_row.Table_Name
          AND Column_Name = sequence_row.Column_Name;    
        
    END LOOP;

    CLOSE sequence_cursor;
END;
/

-- Genel Durum
SELECT * FROM SEQUENCE_INFO 
-- Filtre: Sequence güncellenmesine ihtiyaç duyulan tablolar
WHERE SEQUPDATENEEDED = 1;
/

DECLARE
    CURSOR sequence_update_cursor IS SELECT * FROM SEQUENCE_INFO WHERE SEQUPDATENEEDED = 1;
    sequence_update_row SEQUENCE_INFO%ROWTYPE;
    dynamic_update_sql VARCHAR2(1000);
BEGIN
    OPEN sequence_update_cursor;
    LOOP
        FETCH sequence_update_cursor INTO sequence_update_row;
        EXIT WHEN sequence_update_cursor%NOTFOUND;

        -- Dinamik SQL ifadesini oluştur
        dynamic_update_sql := 'ALTER TABLE "' 
        				   || sequence_update_row.Schema || '"."' || sequence_update_row.Table_Name 
        				   || '" MODIFY "' || sequence_update_row.Column_Name 
        				   || '" GENERATED '
        				   || sequence_update_row.Generation_Type
        				   || ' AS IDENTITY(START WITH ' 
        				   || sequence_update_row.Expected_Seq_Id
        				   || ' INCREMENT BY '
        				   || sequence_update_row.Increment_By
        				   || ');';
        				  
        DBMS_OUTPUT.PUT_LINE(dynamic_update_sql);			  

    END LOOP;
    CLOSE sequence_update_cursor;
END;
/

