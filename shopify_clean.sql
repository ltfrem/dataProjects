------
/*
Data cleaning using SQL. This data was pulled into a data lake using Shopify's API and many records do not have first name
and last name input correctly. This pulls that data from the billing_notes column where it is available and populates
the first and last name fields, improving ~20,000 records.
*/

------
--Look at how many records are missing first and last name but have billing notes
------
SELECT COUNT(*) 
FROM edw.dbo.dimShopify
WHERE first_name IS NULL
AND last_name IS NULL
AND billing_notes IS NOT NULL
--returns 27,568

------
--How many sales records can we link to our guest table?
------
SELECT COUNT(*)
FROM edw.dbo.dimShopify shop
JOIN edw.dbo.dimGuest guest		ON shop.first_name = guest.firstName AND shop.last_name = guest.lastName
--returns ~6,000

------
--The majority of names found in billing notes follow the convention of: "last name, first name (....."
--Extract first name: start at 1 position past where the first comma is found and go until the space before (
--Extract last name: start at position 1 in the string and go until a comma is found (minus 1 position to remove the comma)
------
SELECT 
SUBSTRING(billing_notes, CHARINDEX(',', billing_notes) +1, CHARINDEX(' (', billing_notes) - CHARINDEX(',', billing_notes)) as firstName ,
SUBSTRING(billing_notes, 1, CHARINDEX(',', billing_notes) -1) AS lastName,
billing_notes
FROM edw.dbo.dimShopify
WHERE billing_notes IS NOT NULL
AND billing_notes <> ''
AND CHARINDEX(',', billing_notes) <> 0 --and there is a comma in the billing notes
AND CHARINDEX('(', billing_notes) - CHARINDEX(',', billing_notes) > 0 --and the position of ( is after the comma

------
--Extract first name from the billing notes and insert where first name is null
------
BEGIN TRAN
UPDATE edw.dbo.dimShopify
SET first_name = SUBSTRING(billing_notes, CHARINDEX(',', billing_notes) +1, CHARINDEX(' (', billing_notes) - CHARINDEX(',', billing_notes)) 
WHERE first_name IS NULL
AND billing_notes IS NOT NULL
AND billing_notes <> ''
AND CHARINDEX(',', billing_notes) <> 0 --and there is a comma in the billing notes
AND CHARINDEX('(', billing_notes) - CHARINDEX(',', billing_notes) > 0 --and the position of ( is after the comma

COMMIT

------
--Extract last name from the billing notes and insert where last name is null
------
BEGIN TRAN
UPDATE edw.dbo.dimShopify
SET last_name =   SUBSTRING(billing_notes, 1, CHARINDEX(',', billing_notes) -1)
WHERE last_name IS NULL
AND billing_notes IS NOT NULL
AND billing_notes <> ''
AND CHARINDEX(',', billing_notes) <> 0 --and there is a comma in the billing notes
AND CHARINDEX('(', billing_notes) - CHARINDEX(',', billing_notes) > 0 --and the position of ( is after the comma

COMMIT

------
--This same query from above now returns 676
------
SELECT COUNT(*) 
FROM edw.dbo.dimShopify
WHERE first_name IS NULL
AND last_name IS NULL
AND billing_notes IS NOT NULL

------
--Cleaning up first_name field so queries return more accurate results
------

------
--How many records have an extra space in the first_name column?
------
SELECT COUNT(*) 
FROM edw.dbo.dimShopify
WHERE CHARINDEX(' ', first_name) = 1
--returns 19,029

------
--Remove the extra space
------
BEGIN TRAN
UPDATE edw.dbo.dimShopify
SET first_name = STUFF(first_name, 1, 1, '')
WHERE CHARINDEX(' ', first_name) = 1

COMMIT

------
--Now 0 records have a space as the first character of first_name
------
SELECT COUNT(*) 
FROM edw.dbo.dimShopify
WHERE CHARINDEX(' ', first_name) = 1
--returns 0

------
--Same query from above that tells us how many sales records we can link to our guest table
------
SELECT COUNT(*)
FROM edw.dbo.dimShopify shop
JOIN edw.dbo.dimGuest guest		ON shop.first_name = guest.firstName AND shop.last_name = guest.lastName
--now returns ~25,000