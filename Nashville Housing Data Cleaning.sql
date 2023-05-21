/*

Cleaning Nashville Housing data with SQL queries

*/


-- First look at the data
SELECT 
	* 
FROM 
	PortfolioProject..NashvilleHousing



/* 
Dealing with NULL values 
*/ 

-- Looking at number of NULL values in the PropertyAddress column
SELECT 
	COUNT(*) AS 'No. of NULL values'
FROM 
	PortfolioProject..NashvilleHousing
WHERE 
	PropertyAddress IS NULL

-- ParcelID is unique for every PropertyAddress, so we can use the ParcelID column to help fill in missing PropertyAddress values
-- The New_Property_Address column is used to check what will be inputed into PropertyAddress by the ISNULL function when there is a NULL value
SELECT 
	a.ParcelID, 
	a.PropertyAddress, 
	b.ParcelID, 
	b.PropertyAddress, 
	ISNULL(a.PropertyAddress,b.PropertyAddress) AS 'New_Property_Address'
FROM 
	PortfolioProject..NashvilleHousing a
	JOIN PortfolioProject..NashvilleHousing b ON a.ParcelID = b.ParcelID
	AND a.[UniqueID ] <> b.[UniqueID ] 
WHERE 
	a.PropertyAddress IS NULL

-- Replacing NULL values with PropertyAddress based on ParcelID
UPDATE a
SET PropertyAddress = ISNULL(a.PropertyAddress,b.PropertyAddress)
FROM 
	PortfolioProject..NashvilleHousing a
	JOIN PortfolioProject..NashvilleHousing b ON a.ParcelID = b.ParcelID
	AND a.[UniqueID ] <> b.[UniqueID ]
WHERE 
	a.PropertyAddress IS NULL



/*
Removing duplicates
*/

-- Some rows in the data set show indentical information despite having different unique ids,
-- so we will group each row with partition by and assign it a row number. Rows with row number > 1 
-- have identical information to the previous row, so will delete the duplicate rows.
WITH RowNumCTE AS(
SELECT 
	*,
	ROW_NUMBER() OVER(
	PARTITION BY ParcelID, 
				 PropertyAddress, 
				 SalePrice, 
				 SaleDate, 
				 LegalReference 
				 ORDER BY 
					UniqueID) AS 'row_num'
FROM 
	PortfolioProject..NashvilleHousing
)
DELETE 
FROM 
	RowNumCTE
WHERE 
	row_num > 1



/* 
Standardising Date Format 
*/ 

-- We want the new Date column to look like this
SELECT 
	SaleDate, 
	CONVERT(Date, SaleDate) AS New_Date
FROM 
	PortfolioProject..NashvilleHousing

-- Creating a new column to store our new value for SaleDate
ALTER TABLE PortfolioProject..NashvilleHousing
ADD NewSaleDate Date

-- Adding the Date values to our new column
UPDATE PortfolioProject..NashvilleHousing
SET NewSaleDate = CONVERT(Date, SaleDate)



/*
Separating city from Address for PropertyAddress and putting it into a new column
*/

-- This is what the PropertyAddress column currently looks like
SELECT 
	PropertyAddress
FROM 
	PortfolioProject..NashvilleHousing

-- We will split the PropertyAddress using the substring function into Address and City and this is what it should look like
SELECT
	SUBSTRING(PropertyAddress,1,CHARINDEX(',',PropertyAddress) - 1) AS Address,
	SUBSTRING(PropertyAddress,CHARINDEX(',',PropertyAddress) + 1, LEN(PropertyAddress)) AS City
FROM 
	PortfolioProject..NashvilleHousing

-- Creating new columns to store Address and City 
ALTER TABLE PortfolioProject..NashvilleHousing
ADD 
PropertySplitAddress nvarchar(255),
PropertySplitCity nvarchar(255)

-- Updating the new columns with the separated values
UPDATE PortfolioProject..NashvilleHousing
SET 
PropertySplitAddress = SUBSTRING(PropertyAddress,1,CHARINDEX(',',PropertyAddress) - 1),
PropertySplitCity = SUBSTRING(PropertyAddress,CHARINDEX(',',PropertyAddress) + 1, LEN(PropertyAddress))



/*
Separating Address, City and State for OwnerAddress and putting them into new columns
*/

-- This what OwnerAddress looks like right now
SELECT
	OwnerAddress
FROM 
	PortfolioProject..NashvilleHousing

-- We will use the parsename function here to separate the OwnerAddress and this is what we expect it to look like
SELECT
	PARSENAME(REPLACE(OwnerAddress,',','.'), 3) AS 'OwnerSplitAddress',
	PARSENAME(REPLACE(OwnerAddress,',','.'), 2) AS 'OwnerSplitCity', 
	PARSENAME(REPLACE(OwnerAddress,',','.'), 1) AS 'OwnerSplitState'
FROM 
	PortfolioProject..NashvilleHousing

-- Creating new columns to store the separated values
ALTER TABLE PortfolioProject..NashvilleHousing
ADD 
OwnerSplitAddress nvarchar(255),
OwnerSplitCity nvarchar(255),
OwnerSplitState nvarchar(255)

-- Updating the new columns with the separated values
UPDATE PortfolioProject..NashvilleHousing
SET 
OwnerSplitAddress = PARSENAME(REPLACE(OwnerAddress,',','.'), 3),
OwnerSplitCity = PARSENAME(REPLACE(OwnerAddress,',','.'), 2),
OwnerSplitState = PARSENAME(REPLACE(OwnerAddress,',','.'), 1)
FROM PortfolioProject..NashvilleHousing



/*
Change Y and N to Yes and No in "SoldAsVacant" column for consistency
*/

-- Currently the SoldAsVacant uses both 'Y' and 'Yes' and both 'N' and 'No' in the same column 
SELECT 
	DISTINCT(SoldAsVacant), 
	COUNT(SoldAsVacant) AS 'Count'
FROM 
	PortfolioProject..NashvilleHousing
GROUP BY 
	SoldAsVacant
ORDER BY 
	COUNT(SoldAsVacant)

-- This what we want the SoldAsVacant column to look like
SELECT SoldAsVacant,
CASE 
	WHEN SoldAsVacant = 'Y' THEN 'Yes'
	WHEN SoldAsVacant = 'N' THEN 'No'
	ELSE SoldAsVacant
END
FROM 
	PortfolioProject..NashvilleHousing

-- Updating the SoldAsVacant column for consistency
UPDATE PortfolioProject..NashvilleHousing
SET SoldAsVacant = 
CASE 
	WHEN SoldAsVacant = 'Y' THEN 'Yes'
	WHEN SoldAsVacant = 'N' THEN 'No'
	ELSE SoldAsVacant
END



/*
Deleting unused columns
*/

ALTER TABLE PortfolioProject..NashvilleHousing
DROP COLUMN SaleDate, OwnerAddress, TaxDistrict, PropertyAddress



/*
Creating View for our cleaned data and renaming some columns for clarity
*/

DROP VIEW IF EXISTS NashVilleHousing_Cleaned
USE PortfolioProject
GO
CREATE VIEW NashVilleHousing_Cleaned AS
SELECT 
	UniqueID,
	ParcelID,
	LandUse,
	PropertySplitAddress AS 'PropertyAddress',
	PropertySplitCity AS 'PropertyCity',
	NewSaleDate AS 'SaleDate',
	SalePrice,
	LegalReference,
	SoldAsVacant,
	OwnerName,
	OwnerSplitAddress AS 'OwnerAddress',
	OwnerSplitCity AS 'OwnerCity',
	OwnerSplitState AS 'OwnerState',
	Acreage,
	TaxDistrict,
	LandValue,
	BuildingValue,
	TotalValue,
	YearBuilt,
	Bedrooms,
	FullBath,
	HalfBath
FROM PortfolioProject..NashvilleHousing
GO