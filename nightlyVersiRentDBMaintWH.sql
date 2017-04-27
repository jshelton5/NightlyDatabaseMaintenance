--+==============================================================================================+
--| Program				: nightlyVersiRentDBMaintWH												 |
--| Author				: Joshua Shelton														 |
--| Version				: 3.20170407															 |
--| Purpose				: Performs nightly database maintenance necessary for 					 |
--|                       VersiRent store servers												 |
--|																								 |
--|																								 |
--| Revision 2-29-2016																			 |
--|		+ Reformulated index creation process													 |
--|			a. Instead of dropping and creating, indexes are now only created if they do not	 |
--|             already exist																	 |
--|																								 |
--|		+ Reformulated database integrity checking												 |
--|			a. Instead of using deprecated DBCC command integrity checking is done by 			 |
--|			   stored proc [BuddysDBA].[dbo].[DatabaseIntegrityCheck]							 |
--|																								 |
--|		+ Added a missing index for Datacaster													 |
--|			a. CREATE INDEX [ix_Link_Expires] ON [Datacaster].[dbo].[Link] ([Expires])  		 |
--|             WITH (FILLFACTOR=100, ONLINE=OFF, SORT_IN_TEMPDB=OFF);							 |
--|																								 |
--|		+ Added comments for different sections													 |
--|																								 |
--| Revison 4/8/16																				 |
--|																								 |
--|		+ Added transaction log backups for every 24 hrs.										 |
--|		+ DBCC SHRINKFILE(VersiRentDBLog, TRUNCATEONLY);					                     |
--|																								 |
--| Revison 4/12/16																				 |
--|																								 |
--|		+ Added query to disable auto close db property    									     |
--|																								 |
--|	Revision 5/5/2016																			 |
--|																								 |
--|		+ Altered Index creation to account for multiple index personalities,					 |
--|		  chiral indexes and duplicated indexes													 |
--|																								 |
--|	Revision 5/27/2016																			 |
--|																								 |
--|		+ Added query to purge backup history older than 7 days									 |
--|		+ Added query to clean out command log records older than 30 days						 |
--|																								 |
--|	Revision 7/05/2016																			 |
--|																								 |
--|		+ Added option to set cost threshold for parallelism									 |
--|																								 |
--+==============================================================================================+

--================================================================
/*       Configure query cost threshold for parallelism         */
--================================================================
sp_configure 'show advanced options',1;
GO
RECONFIGURE;
GO

sp_configure 'cost threshold for parallelism',50;
GO
RECONFIGURE;
GO

USE VersiRentDB
GO

--=================================================
/*       TURN OFF AUTO CLOSE DB PROPERTY         */
/*       SET PROPER RECOVERY MODE PER DB         */
--=================================================
ALTER DATABASE VersiRentDB
SET RECOVERY FULL
GO

ALTER DATABASE Datacaster
SET RECOVERY SIMPLE
GO

ALTER DATABASE BuddysDBA
SET RECOVERY SIMPLE
GO

ALTER DATABASE VersiRentDB
SET AUTO_CLOSE OFF
GO

ALTER DATABASE Datacaster
SET AUTO_CLOSE OFF
GO

ALTER DATABASE BuddysDBA
SET AUTO_CLOSE OFF
GO

--=================================================
/*       ADD WINDOWS SECURITY GROUP FOR SA RIGHTS*/
--=================================================
IF NOT EXISTS
	(SELECT name FROM master.sys.server_principals
	 WHERE name='BUDDYRENTS\Store Server Admins')
		CREATE LOGIN [BUDDYRENTS\Store Server Admins] FROM WINDOWS;
		GO
		EXEC sp_addsrvrolemember 'BUDDYRENTS\Store Server Admins', 'sysadmin';
		GO
--=================================================
/*       SET RECEIPT PAPER SIZE TO 3.5"          */
--=================================================
UPDATE Params
SET ParameterValueText=1, Modified=1
WHERE ParamID=1020
AND Terminal > 0
AND Terminal <= 16

UPDATE Params
SET ParameterValueText=1, Modified=1
WHERE ParamID=1025
AND Terminal > 0
AND Terminal <= 16
--=================================================

--=================================================
/* DELETE ANY DATA IN AuditedProductCodes        */
/* DATA IN THIS TABLE HALTS DATA MERGES !!!      */
/* VERY IMPORTANT TO KEEP CLEAN !!!              */
--=================================================
DELETE FROM AuditedProductCodes;
--=================================================

--=================================================
/* CREATE MISSING INDEXES IF THEY DON'T EXIST    */
/* THESE INDEXES SHOULD GO TO VersiRentDB        */
/* This file is laid out alphabetically by table */
--=================================================

--=================================================
--		activity table
--=================================================
IF NOT EXISTS 
	(SELECT Name FROM sysindexes WHERE Name = 'ix_Activity_ACTID_ActivityDate_ActivityCount')
		CREATE INDEX [ix_Activity_ACTID_ActivityDate_ActivityCount] ON [VersiRentDB].[dbo].[Activity] ([ACTID], [ActivityDate], [ActivityCount]) WITH (FILLFACTOR=100, ONLINE=OFF, SORT_IN_TEMPDB=OFF);

--=================================================
--		agrehist table
--=================================================			
IF NOT EXISTS 
	(SELECT Name FROM sysindexes WHERE Name = 'ix_AgreHist_Modified_includes')
		CREATE INDEX [ix_AgreHist_Modified_includes] ON [dbo].[AgreHist] ([Modified]) INCLUDE ([STID],[AHistID],[AgreeID],[InvID],[BinID],[MiscID],[InvTypeID],[Quantity],[LocID],[AStatID],[DateAdded],[DateOff],[DeliverID],[DelivStatID],[DailyRate],[WeeklyRate],[SemiRate],[MonthlyRate],[CashPrice],[InvCondID],[PackageID],[LastModDateTime],[GroupID],[TotalIncome],[MTDIncome],[YTDIncome],[RemainingTerm],[SwappedIncome],[FlexUsed],[ChangedBy]) WITH (FILLFACTOR=100, ONLINE=OFF,SORT_IN_TEMPDB=OFF)

--=================================================
--		agreemnt table
--=================================================	
IF NOT EXISTS 
	(SELECT Name FROM sysindexes WHERE Name='ix_Agreemnt_STID_AStatID_includes')
		CREATE INDEX [ix_Agreemnt_STID_AStatID_includes] ON [VersiRentDB].[dbo].[Agreemnt] ([STID], [AStatID])  INCLUDE ([CustID]) WITH (FILLFACTOR=100, ONLINE=OFF, SORT_IN_TEMPDB=OFF);

IF NOT EXISTS 
	(SELECT Name FROM sysindexes WHERE Name='ix_Agreemnt_STID_PayModeID_includes')
		CREATE INDEX [ix_Agreemnt_STID_PayModeID_includes] ON [dbo].[Agreemnt] ([STID],[PayModeID]) INCLUDE ([AStatID],[WeeklyRate]) WITH (FILLFACTOR=100, ONLINE=OFF, SORT_IN_TEMPDB=OFF);

IF NOT EXISTS 
	(SELECT Name FROM sysindexes WHERE Name='ix_Agreemnt_AStatID_includes')
		CREATE INDEX [ix_Agreemnt_AStatID_includes] ON [dbo].[Agreemnt] ([AStatID]) INCLUDE ([STID],[AgreeID],[AgreementNumber],[CustID],[Term],[CreditsPaid],[PayModeID],[DailyRate],[WeeklyRate],[SemiRate],[MonthlyRate],[DWDaily],[DWWeekly],[DWSemi],[DWMonthly],[DueDate],[RentalDeferment],[LateDeferment],[DWDeferment],[TripCharge],[NSFCharges],[Semi1stPay],[Semi2ndPay],[TaxID],[MonthlyClubRate],[WeeklyClubRate],[ClubDeferment],[ClubAgreement],[DeliveryDeferment],[InitialDeferment],[DWFlag],[DailyClubRate],[SemiClubRate],[RentToRent]) WITH (FILLFACTOR=100, ONLINE=OFF, SORT_IN_TEMPDB=OFF);

--=================================================
--		agreementanalysis table
--=================================================		
IF NOT EXISTS 
	(SELECT Name FROM sysindexes WHERE Name = 'ix_AgreementAnalysis_STID_AADate_AgrAnalTypeID_includes')
		CREATE INDEX [ix_AgreementAnalysis_STID_AADate_AgrAnalTypeID_includes] ON [VersiRentDB].[dbo].[AgreementAnalysis] ([STID], [AADate], [AgrAnalTypeID])  INCLUDE ([Total]) WITH (FILLFACTOR=100, ONLINE=OFF, SORT_IN_TEMPDB=OFF);

IF NOT EXISTS 
	(SELECT Name FROM sysindexes WHERE Name = 'ix_AgreementAnalysis_includes')
		CREATE INDEX [ix_AgreementAnalysis_includes] ON [dbo].[AgreementAnalysis] ([Modified]) INCLUDE ([STID],[AgreeAnalID],[AADate],[AgrAnalTypeID],[Total],[Currents],[Collectibles],[NonCollectibles],[LastModDateTime]) WITH (FILLFACTOR=100, ONLINE=OFF,SORT_IN_TEMPDB=OFF);
	
--=================================================
--		commitments table
--=================================================	
IF NOT EXISTS 
	(SELECT Name FROM sysindexes WHERE Name='ix_Commitments_CommitStatID_AccountTypeID_CommitDate_includes')
		CREATE INDEX [ix_Commitments_CommitStatID_AccountTypeID_CommitDate_includes] ON [VersiRentDB].[dbo].[Commitments] ([CommitStatID], [AccountTypeID], [CommitDate])  INCLUDE ([STID], [CommitID], [CustClubID], [CWSCID], [AgreeID], [InvcID], [NSFID]) WITH (FILLFACTOR=100, ONLINE=OFF, SORT_IN_TEMPDB=OFF);

--=================================================
--		custclubpayhist table
--=================================================
IF NOT EXISTS 
	(SELECT Name FROM sysindexes WHERE Name = 'ix_CustClubPayHist_Modified_includes')	
		CREATE INDEX [ix_CustClubPayHist_Modified_includes] ON [VersiRentDB].[dbo].[CustClubPayHist] ([Modified])  INCLUDE ([STID], [CClubPayHistID], [CustClubID], [PaymentDate], [NextDueDate], [PrevDueDate], [PayModeID], [PaymentAmount], [PaymentTax], [EmployeeID], [PayLocID], [PayTypeID], [ClubAmount], [WaiverAmount], [ClubDeferred], [WaiverDeferred], [FreeMoney], [FreeMoneyID], [FreeDays], [FreeDayID], [NumberMade], [ReceiptNumber], [WasVoided], [ConvenienceFee], [FieldReceiptNum], [MasterPayID], [LastModDateTime]) WITH (FILLFACTOR=100, ONLINE=OFF, SORT_IN_TEMPDB=OFF);

--=================================================
--		customerreferences table
--=================================================
IF NOT EXISTS 
	(SELECT Name FROM sysindexes WHERE Name = 'ix_CustomerReferences_STID_CustID_PeopleID_CustRefID_Relation_Deleted_Modified_LastModDateTime')
		CREATE INDEX [ix_CustomerReferences_STID_CustID_PeopleID_CustRefID_Relation_Deleted_Modified_LastModDateTime] ON [VersiRentDB].[dbo].[CustomerReferences] ([STID],[CustID],[PeopleID],[CustRefID],[Relation],[Deleted],[Modified],[LastModDateTime]) WITH (FILLFACTOR=100, ONLINE=OFF, SORT_IN_TEMPDB=OFF);
		
--=================================================
--		cwscontacts table
--=================================================	
IF NOT EXISTS 
	(SELECT Name FROM sysindexes WHERE Name='ix_CWSContacts_CWSCID')
		CREATE INDEX [ix_CWSContacts_CWSCID] ON [VersiRentDB].[dbo].[CWSContacts] ([CWSCID])  WITH (FILLFACTOR=100, ONLINE=OFF, SORT_IN_TEMPDB=OFF);

--=================================================
--		depreciationrundetail table
--=================================================	
IF NOT EXISTS 
	(SELECT Name FROM sysindexes WHERE Name='ix_DepreciationRunDetail_Modified_includes')
		CREATE INDEX [ix_DepreciationRunDetail_Modified_includes] ON [VersiRentDB].[dbo].[DepreciationRunDetail] ([Modified])  INCLUDE ([STID], [DRDetailID], [DepreciationRunID], [InvID], [StockNumber], [Brand], [Model], [Serial], [DateOfStock], [FirstOutDate], [Life], [InvCost], [AdjustedCost], [AccumulatedIncome], [MonthlyIncome], [DepreciationYear], [FYTDDepreciation], [MonthsDepreciation], [AccumulatedDepreciation], [BookValue], [InvStatID], [DisposalDate], [LastModDateTime], [AccumDeprLastMonth], [DepreciationMonth], [TransferComplete], [DeprStartDate], [TransferTo], [DeprAdjustment]) WITH (FILLFACTOR=100, ONLINE=OFF, SORT_IN_TEMPDB=OFF);

--=================================================
--		employee table
--=================================================
IF NOT EXISTS 
	(SELECT Name FROM sysindexes WHERE Name='ix_Employee_InActive_includes')
		CREATE INDEX [ix_Employee_InActive_includes] ON [dbo].[Employee] ([InActive]) INCLUDE ([EmployeeID],[FirstName],[LastName],[MiddleInitial],[PasswordExpires]) WITH (FILLFACTOR=100, ONLINE=OFF, SORT_IN_TEMPDB=OFF);

--=================================================
--		employeegrouplink table
--=================================================	
IF NOT EXISTS 
	(SELECT Name FROM sysindexes WHERE Name='ix_EmployeeGroupLink_EmpGLinkID_EmployeeID_EGroupTypeID_LevelID')
		CREATE INDEX [ix_EmployeeGroupLink_EmpGLinkID_EmployeeID_EGroupTypeID_LevelID] on [dbo].[EmployeeGroupLink] ([EmpGLinkID],[EmployeeID],[EGroupTypeID],[LevelID]) WITH (FILLFACTOR=100,ONLINE=OFF,SORT_IN_TEMPDB=OFF);
	
--=================================================
--		employeesummary table
--=================================================
IF NOT EXISTS 
	(SELECT Name FROM sysindexes WHERE Name = 'ix_EmployeeSummaryID_EmployeeID_Date_Amount_EmployeeSummaryTypeID_STID_LastModDateTime')
		CREATE INDEX [ix_EmployeeSummaryID_EmployeeID_Date_Amount_EmployeeSummaryTypeID_STID_LastModDateTime] ON [VersiRentDB].[dbo].[EmployeeSummary] ([EmployeeSummaryID], [EmployeeID], [Date], [Amount], [EmployeeSummaryTypeID], [STID], [Modified], [LastModDateTime]) WITH (FILLFACTOR=100, ONLINE=OFF, SORT_IN_TEMPDB=OFF);

IF NOT EXISTS 
	(SELECT Name FROM sysindexes WHERE Name = 'ix_EmployeeSummary_Modified_includes')
		CREATE INDEX [ix_EmployeeSummary_Modified_includes] ON [dbo].[EmployeeSummary] ([Modified]) INCLUDE ([EmployeeSummaryID],[EmployeeID],[Date],[Amount],[EmployeeSummaryTypeId],[STID],[LastModDateTime]) WITH (FILLFACTOR=100, ONLINE=OFF, SORT_IN_TEMPDB=OFF)

--=================================================
--		exceptions table
--=================================================	
IF NOT EXISTS 
	(SELECT Name FROM sysindexes WHERE Name='ix_Exceptions_Modified')
		CREATE INDEX [ix_Exceptions_Modified] ON [VersiRentDB].[dbo].[Exceptions] ([Modified])  WITH (FILLFACTOR=100, ONLINE=OFF, SORT_IN_TEMPDB=OFF);

--=================================================
--		generalledger table
--=================================================	
IF NOT EXISTS 
	(SELECT Name FROM sysindexes WHERE Name='ix_GeneralLedger_Modified_includes')
		CREATE INDEX [ix_GeneralLedger_Modified_includes] ON [dbo].[GeneralLedger] ([Modified]) INCLUDE (STID,LedgerID,LedgerDateTime,DebitCredit,EntryAccount,EntryAmount,LedgerState,LastModDateTime,AccountDescription,SequenceNumber,AccountTypeID,DeptID,MiscID,ExpCatID,COReasonID,SCOReasonID) WITH (FILLFACTOR=100, ONLINE=OFF, SORT_IN_TEMPDB=OFF);

--=================================================
--		income table
--=================================================	
IF NOT EXISTS 
	(SELECT Name FROM sysindexes WHERE Name='ix_Income_STID_IncTypeID_IncomeDate_includes')
		CREATE INDEX [ix_Income_STID_IncTypeID_IncomeDate_includes] ON [VersiRentDB].[dbo].[Income] ([STID], [IncTypeID], [IncomeDate])  INCLUDE ([Amount]) WITH (FILLFACTOR=100, ONLINE=OFF, SORT_IN_TEMPDB=OFF);

--=================================================
--		invntry table
--=================================================			
IF NOT EXISTS 
	(SELECT Name FROM sysindexes WHERE Name='ix_Invntry_InvStatID_includes')
		CREATE INDEX [ix_Invntry_InvStatID_includes] ON [dbo].[Invntry] ([InvStatID]) INCLUDE ([STID],[InvID],[StockNumber],[ModID],[Serial],[VendID],[Cost],[RepairCost],[BORFlag],[DateOfStock],[DisposalDate],[FirstOut],[LastOut],[LastIn],[TotalIncome],[TransferDate],[TransferTo],[InternalBookValue],[TransferOutDate],[TermSp],[DailySp],[WeeklySp],[SemiSp],[MonthlySp],[LocID],[InvServStatID]) WITH (FILLFACTOR=100, ONLINE=OFF, SORT_IN_TEMPDB=OFF)
		
--=================================================
--		inventoryincomehistory table
--=================================================
IF NOT EXISTS 
	(SELECT Name FROM sysindexes WHERE Name = 'ix_InventoryIncomeHistory_Modified_includes')
		CREATE INDEX [ix_InventoryIncomeHistory_Modified_includes] ON [dbo].[InventoryIncomeHistory] ([Modified]) INCLUDE ([STID],[InvIncomeHistID],[AgreementNumber],[Term],[CreditsPaid],[DailyRate],[WeeklyRate],[SemiRate],[MonthlyRate],[PayModeID],[InvID],[Amount],[IncDate],[EmployeeID],[LastModDateTime]) WITH (FILLFACTOR=100, ONLINE=OFF, SORT_IN_TEMPDB=OFF)
		
--=================================================
--		masterledger table
--=================================================
IF NOT EXISTS 
	(SELECT Name FROM sysindexes WHERE Name = 'ix_MasterLedger_STID_SequenceNumber_Distributions_Modified_LastModDateTime')
		CREATE INDEX [ix_MasterLedger_STID_SequenceNumber_Distributions_Modified_LastModDateTime] ON [VersiRentDB].[dbo].[MasterLedger] ([STID], [SequenceNumber], [Distributions], [Modified], [LastModDateTime] ) WITH (FILLFACTOR=100, ONLINE=OFF, SORT_IN_TEMPDB=OFF);

IF NOT EXISTS 
	(SELECT Name FROM sysindexes WHERE Name = 'ix_MasterLeger_Modified_includes')
		CREATE INDEX [ix_MasterLeger_Modified_includes] ON [dbo].[MasterLedger] ([Modified]) INCLUDE ([STID],[SequenceNumber],[Distributions],[LastModDateTime]) WITH (FILLFACTOR=100, ONLINE=OFF, SORT_IN_TEMPDB=OFF)

--=================================================
--		masterpayment table
--=================================================	
IF NOT EXISTS 
	(SELECT Name FROM sysindexes WHERE Name='ix_MasterPayment_STID_CustID_includes')
		CREATE INDEX [ix_MasterPayment_STID_CustID_includes] ON [VersiRentDB].[dbo].[MasterPayment] ([STID], [CustID])  INCLUDE ([MasterPayID], [PaymentDate], [ReceiptNumber]) WITH (FILLFACTOR=100, ONLINE=OFF, SORT_IN_TEMPDB=OFF);
		
IF NOT EXISTS 
	(SELECT Name FROM sysindexes WHERE Name='ix_MasterPayment_Modified_includes')		
		CREATE INDEX [ix_MasterPayment_Modified_includes] ON [VersiRentDB].[dbo].[MasterPayment] ([Modified])  INCLUDE ([STID], [MasterPayID], [CustID], [PaymentDate], [ReceiptNumber], [PayTypeID], [PayLocID], [EmployeeID], [ConvenienceFee], [FieldReceiptNum], [OtherSTID], [WasVoided], [IsPriorToMaster], [LastModDateTime], [OriginalSTID], [VoidedMasterPayID]) WITH (FILLFACTOR=100, ONLINE=OFF, SORT_IN_TEMPDB=OFF);
	
--=================================================
--		model table
--=================================================
IF NOT EXISTS
	(SELECT Name FROM sysindexes WHERE Name='ix_Model_PCID_ModStatID_includes')
		CREATE INDEX [ix_Model_PCID_ModStatID_includes] ON [dbo].[Model] ([PCID],[ModStatID]) INCLUDE ([ModID],[ModelNumber]) WITH (FILLFACTOR=100, ONLINE=OFF, SORT_IN_TEMPDB=OFF)

--=================================================
--		modelattributes table
--=================================================
IF NOT EXISTS
	(SELECT Name FROM sysindexes WHERE Name='ix_ModelAttributes_includes')
		CREATE INDEX [ix_ModelAttributes_includes] ON [dbo].[ModelAttributes] ([Modified]) INCLUDE ([ModAttribID],[AttributeID],[ModID],[LastModDateTime]) WITH (FILLFACTOR=100, ONLINE=OFF,SORT_IN_TEMPDB=OFF);

		--=================================================
--		modelmarket table
--=================================================
IF NOT EXISTS
	(SELECT Name FROM sysindexes WHERE Name='ix_ModelMarket_Modified_includes')
		CREATE INDEX [ix_ModelMarket_Modified_includes] ON [VersiRentDB].[dbo].[ModelMarket] ([Modified])  INCLUDE ([MMID], [ModID], [MarketID], [Term], [DailyRate], [WeeklyRate], [SemiRate], [MonthlyRate], [OriginalCost], [StandardCost], [LastItemCost], [RetailPrice], [MSRP], [MaximumLevelInventory], [MinimumLevelInventory], [Term2], [DailyRate2], [WeeklyRate2], [SemiRate2], [MonthlyRate2], [LastModDateTime]) WITH (FILLFACTOR=100, ONLINE=OFF, SORT_IN_TEMPDB=OFF);

--=================================================
--		modlvend table
--=================================================
IF NOT EXISTS
	(SELECT Name FROM sysindexes WHERE Name='ix_ModlVend_includes')
		CREATE INDEX [ix_ModlVend_includes] ON [dbo].[ModlVend] ([Modified]) INCLUDE ([ModVendID],[ModID],[VendID],[Removed],[LastModDateTime],[CatalogNumber]) WITH (FILLFACTOR=100, ONLINE=OFF,SORT_IN_TEMPDB=OFF);

--=================================================
--		params table
--=================================================		
IF NOT EXISTS
	(SELECT Name FROM sysindexes WHERE Name='ix_Params_ParamID_STID_includes')
		CREATE INDEX [ix_Params_ParamID_STID_includes] ON [dbo].[Params] ([ParamID],[STID]) INCLUDE ([ParameterValueText]) WITH (FILLFACTOR=100, ONLINE=OFF, SORT_IN_TEMPDB=OFF);

--=================================================
--		payhist table
--=================================================
IF NOT EXISTS 
	(SELECT Name FROM sysindexes WHERE Name = 'ix_PayHist_STID_AgreeID_PayTypeID_PaymentID_PaymentDate_Rental_ExemptDats_WasVoided')
		CREATE INDEX [ix_PayHist_STID_AgreeID_PayTypeID_PaymentID_PaymentDate_Rental_ExemptDats_WasVoided] ON [VersiRentDB].[dbo].[PayHist] ([STID], [AgreeID], [PayTypeID], [PaymentID], [PaymentDate], [Rental], [ExemptDays], [WasVoided]) WITH (FILLFACTOR=100, ONLINE=OFF, SORT_IN_TEMPDB=OFF);

IF NOT EXISTS 
	(SELECT Name FROM sysindexes WHERE Name = 'ix_PayHist_Modified_includes')		
		CREATE INDEX [ix_PayHist_Modified_includes] ON [VersiRentDB].[dbo].[PayHist] ([Modified])  INCLUDE ([STID], [PaymentID], [AgreeID], [PaymentDate], [DueDate], [PrevDueDate], [CreditsPaid], [Rental], [LateCharge], [DamageWaiver], [Tax], [TripCharge], [DefermentBalance], [ExtendedWarranty], [EmployeeID], [NSFFees], [PayLocID], [ClubPayment], [ClubNextDueDate], [FreeMoney], [FreeDays], [PayModeID], [ClubCreditsPaid], [ClubPayModeId], [LateChargeAssessed], [LateChargeAssessedStored], [AddRate1SalesTax], [AddRate2SalesTax], [AddRate3SalesTax], [RegularPayModeID], [BonusPointsEarned], [ReceiptNumber], [DeliveryFee], [InitialFee], [PayTypeID], [RentalDeferred], [DWDeferred], [LateDeferred], [TripDeferred], [ClubDeferred], [DeliveryDeferred], [InitialDeferred], [NSFDeferred], [FreeRental], [FreeDW], [FreeLate], [FreeTrip], [FreeClub], [FreeDelivery], [FreeInitial], [FreeNSF], [DaysLate], [LastModDateTime], [FreeMoneyID], [FreeDayID], [DepositUsed], [DepositConverted], [DepositRefunded], [WasVoided], [Buyout], [OtherSTID], [ClubID], [ConvenienceFee], [FieldReceiptNum], [MasterPayID], [ExemptDays], [ExemptMoney], [ExemptRental], [ExemptDW], [ExemptClub], [ExemptLate], [ExemptTrip], [ExemptDelivery], [ExemptInitial], [BonusBucksPaid], [BonusBucksEarned], [BonusBucksBalance], [DepositReceived]) WITH (FILLFACTOR=100, ONLINE=OFF, SORT_IN_TEMPDB=OFF);

--=================================================
--		people table                                
--=================================================
IF NOT EXISTS 
	(SELECT Name FROM sysindexes WHERE Name = 'ix_People_PeopleID_FirstName_LastName_MiddleName_Title_Suffix_MailingAddress_MailingApt_MailingZip')
		CREATE INDEX [ix_People_PeopleID_FirstName_LastName_MiddleName_Title_Suffix_MailingAddress_MailingApt_MailingZip] ON [VersiRentDB].[dbo].[People] ([PeopleID],[FirstName],[LastName],[MiddleName],[Title],[Suffix],[MailingAddress],[MailingApt],[MailingZip]) WITH (FILLFACTOR=100, ONLINE=OFF, SORT_IN_TEMPDB=OFF);

--=================================================
--		peoplephones table
--=================================================
IF NOT EXISTS 
	(SELECT Name FROM sysindexes WHERE Name = 'ix_PeoplePhone_includes')
		CREATE INDEX [ix_PeoplePhone_includes] ON [VersiRentDB].[dbo].[PeoplePhones] ([STID],[PeopleID],[PPhoneID],[PhoneNumber],[Extension],[IsPrimary],[IsSMS],[Deleted],[Modified],[LastModDateTime], [CRMPPhoneID]) 
			INCLUDE ([OptInMarketingText], [OptInMarketingCall], [OptInReminderText], [OptInReminderCall], [OptInCollectionText], [OptInCollectionCall] ) WITH (FILLFACTOR=100, ONLINE=OFF, SORT_IN_TEMPDB=OFF);

IF NOT EXISTS 
	(SELECT Name FROM sysindexes WHERE Name = 'ix_PeoplePhones_STID_Deleted_IsPrimary_includes')
		CREATE INDEX [ix_PeoplePhones_STID_Deleted_IsPrimary_includes] ON [dbo].[PeoplePhones] ([STID],[Deleted],[IsPrimary]) INCLUDE ([PeopleID],[PhoneNumber]) WITH (FILLFACTOR=100, ONLINE=OFF, SORT_IN_TEMPDB=OFF)

--=================================================
--		peoplepic table
--=================================================	
IF NOT EXISTS 
	(SELECT Name FROM sysindexes WHERE Name='IX_PeoplePic_PeopleID_STID')
		CREATE INDEX [IX_PeoplePic_PeopleID_STID] ON [VersiRentDB].[dbo].[PeoplePic] ([PeopleID], [STID]) WITH (FILLFACTOR=100, ONLINE=OFF, SORT_IN_TEMPDB=OFF);

--=================================================
--		smsmessagedetails table
--=================================================
IF NOT EXISTS 
	(SELECT Name FROM sysindexes WHERE Name = 'ix_SMSMessageDetails_SMSMessageQueueID_SMSMessageDetailID_SMSStatusID_Created_ToPerson_EmployeeID')
		CREATE INDEX [ix_SMSMessageDetails_SMSMessageQueueID_SMSMessageDetailID_SMSStatusID_Created_ToPerson_EmployeeID] ON [VersiRentDB].[dbo].[SMSMessageDetails] ([SMSMessageQueueID],[SMSMessageDetailID],[SMSStatusID],[Created],[ToPerson],[EmployeeID]) WITH (FILLFACTOR=100, ONLINE=OFF, SORT_IN_TEMPDB=OFF);

IF NOT EXISTS 
	(SELECT Name FROM sysindexes WHERE Name = 'ix_SMSMessageDetails_Modified')
		CREATE INDEX [ix_SMSMessageDetails_Modified] ON [dbo].[SMSMessageDetails] ([Modified]) WITH (FILLFACTOR=100, ONLINE=OFF, SORT_IN_TEMPDB=OFF)

--=================================================
--		storestatistics table
--=================================================		
IF NOT EXISTS 
	(SELECT Name FROM sysindexes WHERE Name = 'ix_StoreStatistics_SSTypeID_STID_SSDate_includes') 
		CREATE INDEX [ix_StoreStatistics_SSTypeID_STID_SSDate_includes] ON [VersiRentDB].[dbo].[StoreStatistics] ([SSTypeID], [STID], [SSDate])  INCLUDE ([Value]) WITH (FILLFACTOR=100, ONLINE=OFF, SORT_IN_TEMPDB=OFF);

--=================================================
--		transact table
--=================================================	
IF NOT EXISTS
	(SELECT Name FROM sysindexes WHERE Name='ix_Transact_Modified_includes')
		CREATE INDEX [ix_Transact_Modified_includes] ON [dbo].[Transact] ([Modified]) INCLUDE (STID,TransID,TransactionDate,SystemDate,TransactionTime,AgreeID,CustID,Route,EmployeeID,InvoiceNumber,ReceiptNumber,LastModDateTime,TransTID,GLSequence,TerminalID,Body,VersionStr) WITH (FILLFACTOR=100, ONLINE=OFF, SORT_IN_TEMPDB=OFF);

--=================================================
--		transfers table
--=================================================
IF NOT EXISTS
	(SELECT Name FROM sysindexes WHERE Name='ix_Transfers_Modified_includes')
		CREATE INDEX [ix_Transfers_Modified_includes] ON [VersiRentDB].[dbo].[Transfers] ([Modified])  INCLUDE ([STID], [TransferID], [TransferTypeID], [FromSTID], [ToSTID], [TransferStatID], [TransferOutDate], [TransferInDate], [InvID], [BinID], [StockNumber], [ModelNumber], [ProductCode], [Serial], [ModelDescription], [Quantity], [TransferInfo], [LastModDateTime], [CrossReferenceID], [RecordDate], [VoidRejectDate], [TransMediaTypeID]) WITH (FILLFACTOR=100, ONLINE=OFF, SORT_IN_TEMPDB=OFF);

--=================================================
/* CREATE ADDITIONAL INDEXES IF THEY DON'T EXIST */
/* THESE INDEXES GO TO Datacaster                */
--=================================================

USE Datacaster
GO

--=================================================
--	 Authentication table
--=================================================
IF NOT EXISTS 
	(SELECT Name from sysindexes WHERE Name='ix_Authentication_AuthenticationUID')
		CREATE INDEX [ix_Authentication_AuthenticationUID] ON [dbo].[Authentication] ([AuthenticationUID]) WITH (FILLFACTOR=100, ONLINE=OFF, SORT_IN_TEMPDB=OFF);

--=================================================
--	 AuthenticationRole table
--=================================================
IF NOT EXISTS 
	(SELECT Name from sysindexes WHERE Name='ix_DocumentRoles_DocumentUID')
		CREATE INDEX [ix_AuthenticationRole_AuthenticationUID] ON [dbo].[AuthenticationRole] ([AuthenticationUID]) WITH (FILLFACTOR=100, ONLINE=OFF, SORT_IN_TEMPDB=OFF);

--=================================================
--	 DocumentRoles table
--=================================================
IF NOT EXISTS 
	(SELECT Name from sysindexes WHERE Name='ix_DocumentRoles_DocumentUID')
		CREATE INDEX [ix_DocumentRoles_DocumentUID] ON [dbo].[DocumentRoles] ([DocumentUID]) WITH (FILLFACTOR=100, ONLINE=OFF, SORT_IN_TEMPDB=OFF);

--=================================================
--	 link table
--=================================================
IF NOT EXISTS 
	(SELECT Name from sysindexes WHERE Name='ix_Link_Expires')
		CREATE INDEX [ix_Link_Expires] ON [Datacaster].[dbo].[Link] ([Expires])  WITH (FILLFACTOR=100, ONLINE=OFF, SORT_IN_TEMPDB=OFF);
		
--=================================================
/* CREATE ADDITIONAL INDEXES IF THEY DON'T EXIST */
/* THESE INDEXES GO TO msdb                      */
--=================================================		
USE msdb
GO
--=================================================
--	 backupset table
--=================================================
IF NOT EXISTS 
	(SELECT Name from sysindexes WHERE Name='backupset_backup_finish_date_includes')
		CREATE INDEX [backupset_backup_finish_date_includes] ON [dbo].[backupset] ([backup_finish_date]) INCLUDE ([media_set_id]) WITH (FILLFACTOR=100, ONLINE=OFF, SORT_IN_TEMPDB=OFF)

--=============================================
/* RE-ORGANIZE OR REINDEX ALL USER DATABASES */
/* REORGANIZATION THRESHOLD BETWEEN 5%-30%   */
/* REINDEX THRESHOLD > 30%                   */
--=============================================
USE BuddysDBA
GO
EXEC dbo.IndexOptimize @Databases = 'USER_DATABASES', @FragmentationLow = NULL, @FragmentationMedium = 'INDEX_REORGANIZE,INDEX_REBUILD_OFFLINE', @FragmentationHigh = 'INDEX_REORGANIZE,INDEX_REBUILD_OFFLINE', @FragmentationLevel1 = 5, @FragmentationLevel2 = 30, @FillFactor=100, @MSShippedObjects = 'Y', @UpdateStatistics = 'ALL', @MaxDOP=1, @LogToTable = 'Y';
--=============================================

--=============================================
/* INTEGRITY CHECK ON ALL DATABASES          */
--=============================================
USE BuddysDBA
GO
exec dbo.DatabaseIntegrityCheck @Databases = 'ALL_DATABASES', @LogToTable = 'Y';
--=============================================

--=============================================
/* AUTOMATICLY ADVANCE THE BUSINESS DATE     */
/* WAREHOUSE VERSIRENT SERVERS ONLY !!!      */
--=============================================
USE VersiRentDB
GO
DECLARE @storeid int;
DECLARE @draweramt money;
DECLARE @empid uniqueidentifier;
DECLARE @ishos int;
DECLARE @cashcount nvarchar(4000);
DECLARE @inDate DATETIME;

SET @storeid=(SELECT dbo.GetIntParam(93,0));
SET @draweramt=CAST((SELECT ParameterValueText FROM Params WHERE ParamID=14) AS MONEY);
SET @empid='{29D320A0-613B-4926-B18F-E3D8B211B033}'; -- VersiRent Automated Process ID: V-A
SET @ishos=CAST((SELECT IsHOS FROM Stores WHERE STID=@storeid) AS INT);
SET @cashcount=NULL;
SET @inDate=(SELECT dbo.GetDateParam(92,@storeid));  --set the stinkin' inDate param

EXEC dbo.CloseBusinessDay @storeid,@draweramt,@empid,@inDate,@ishos,@cashcount

--=============================================

--=============================================
/* DO A TRANSACTION LOG BACKUP 				 */
/* THESE ARE CLEANED UP EVERY 24 HOURS       */
--=============================================
USE BuddysDBA
GO
EXEC dbo.DatabaseBackup @Databases = 'VersiRentDB', @Directory = 'C:\VersiRent\Data', @BackupType = 'LOG', @Verify = 'Y', @Compress = 'N', @CheckSum = 'Y', @CleanupTime = 24;

--=============================================
/*     TRUNCATE THE TRANSACTION LOG FILE     */
--=============================================
USE VersiRentDB
GO
DBCC SHRINKFILE(VersiRentDBLog, TRUNCATEONLY);
--=============================================

--=============================================
/*     Purge backup history from MSDB        */
--=============================================
USE msdb
GO
DECLARE @LatestDate DATETIME2;

SET @LatestDate=DATEADD(day,-7,GETDATE());

EXEC msdb.dbo.sp_delete_backuphistory @oldest_date=@LatestDate
EXEC msdb.dbo.sp_purge_jobhistory @oldest_date=@LatestDate

DBCC SHRINKFILE(MSDBLog, 1);

--=============================================
/*     Purge commandlog history  - 30 days   */
--=============================================
USE BuddysDBA
GO
DELETE FROM CommandLog WHERE StartTime < DATEADD(dd,-30,GETDATE());

