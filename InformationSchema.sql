 
-- Tüm kullanıcılar
SELECT * FROM ALL_USERS WHERE USERNAME LIKE 'Heroty_%';
	  
-- Tüm tablolar
SELECT * FROM ALL_TABLES WHERE OWNER LIKE 'Heroty_%';

-- Tüm sekanslar
SELECT * FROM ALL_SEQUENCES WHERE SEQUENCE_OWNER LIKE 'Heroty_%';

-- Tabloların primary Key ve Sekans bilgileri
SELECT * FROM ALL_TAB_IDENTITY_COLS  WHERE OWNER LIKE 'Heroty_%';

-- Tablo yorumları
SELECT * FROM ALL_TAB_COMMENTS WHERE OWNER LIKE 'Heroty_%';

-- Tablo hareketleri
SELECT * FROM ALL_TAB_MODIFICATIONS WHERE TABLE_OWNER LIKE 'Heroty_%';

-- Tüm kolonlar
SELECT * FROM  ALL_TAB_COLUMNS WHERE OWNER LIKE 'Heroty_%';

-- Kullanılmayan kolonlar
SELECT * FROM ALL_UNUSED_COL_TABS WHERE OWNER LIKE 'Heroty_%';

-- Kullanılmayan kolonlar
SELECT * FROM ALL_ZONEMAPS WHERE OWNER LIKE 'Heroty_%';


	   