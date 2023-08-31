USE [BpmTemplate]
GO
/****** Object:  StoredProcedure [dbo].[DHR_prod_route_sheet_history_qty_input]    Script Date: 31/8/2023 5:11:33 pm ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Ya Dong Zhu
-- Create date: 22 August 2022
-- Description:	this is SP for retrieving the completed qty for current station
--return columns:
				--[Accept Qty], 
				--[Reject Qty],
				--[Test],
				--[Remark / NCIR / TDN],
				--[What has been changed]
-- =============================================
ALTER PROCEDURE [dbo].[DHR_prod_route_sheet_history_qty_input]
	-- Add the parameters for the stored procedure here
	@mode varchar(20), -- either "Create new" or "Amend existing"
    @process_id varchar(40) -- existing process ID -- for "Amend existing"
AS
BEGIN
	BEGIN TRY
    IF  (@mode='Create new') --station is not null
	BEGIN --find related process_id based on squence (latest one)
        select  
        NULL as [Accept Qty], 
        NULL as [Reject Qty], 
        NULL as [Test],
       '' as [Remark / NCIR / TDN],
       '' as [What has been changed]
	END
    ELSE IF (@mode='Amend existing' AND @process_id != 'N/A')
        BEGIN
			select * from (
				select d.label,d.value		
				from  [BsWebService].[dbo].bpm_process_detail d with (nolock)
					inner join [BsWebService].[dbo].bpm_process_matrix m with (nolock) on d.process_matrix_id=m.id 
					inner join [BsWebService].[dbo].bpm_process p with (nolock) on m.process_id=p.id and m.process_revn=p.revn and p.status='close' 
					and p.id=@process_id
					-- and p.id='prd-rs-01-20220821112251'
					and (
						d.label='Accept Qty' or 
						d.label='Reject Qty' or
						d.label='Test' or
						d.label='Remark / NCIR / TDN' or 
						d.label='What has been changed'
						)
				) detailResult  
			PIVOT ( 
				MAX(value)  
				for label in (
					[Accept Qty], 
					[Reject Qty],
					[Test],
					[Remark / NCIR / TDN],
					[What has been changed]
				) 
			) as pivot_table 

        END

	--PRINT N'Process ID is'+@process_id
 	END TRY  
    BEGIN CATCH  

        DECLARE @ErrorMessage NVARCHAR(4000);  
        DECLARE @ErrorSeverity INT;  
        DECLARE @ErrorState INT;  

        SELECT   
            @ErrorMessage = ERROR_MESSAGE(),  
            @ErrorSeverity = ERROR_SEVERITY(),  
            @ErrorState = ERROR_STATE();  

        -- Use RAISERROR inside the CATCH block to return error  
        -- information about the original error that caused  
        -- execution to jump to the CATCH block.  
        RAISERROR (@ErrorMessage, -- Message text.  
                @ErrorSeverity, -- Severity.  
                @ErrorState -- State.  
                );  
    END CATCH; 		
END
