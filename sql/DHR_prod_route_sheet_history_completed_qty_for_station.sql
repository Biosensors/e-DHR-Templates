USE [BpmTemplate]
GO
/****** Object:  StoredProcedure [dbo].[DHR_prod_route_sheet_history_completed_qty_for_station]    Script Date: 31/8/2023 5:08:01 pm ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Ya Dong Zhu
-- Create date: 22 August 2022
-- Description:	this is SP for retrieving the completed qty for current station
--return columns:
				--[line],
				--[From Shift],
				--[Accept Qty], 
				--[Reject Qty],
				--[Test],
				--[Total Completion],
				--[Last Update On]
-- =============================================
ALTER PROCEDURE [dbo].[DHR_prod_route_sheet_history_completed_qty_for_station]
	-- Add the parameters for the stored procedure here
	@mode varchar(20), -- either "Create new" or "Amend existing"
    @order_no varchar(40), -- production order no -- for "Create New"
    @station nvarchar(200), -- station -- for "Create New"
    @process_id varchar(40), -- existing process ID -- for "Amend existing"
    @route_sheet_tmpl_id varchar(40) -- associate with route sheet template name
AS
BEGIN
	BEGIN TRY
    IF  (@mode='Create new' and @order_no!='N/A' and @station!='N/A') --station is not null
	BEGIN --find related process_id based on squence (latest one)
        select  
        [Shift] as [From Shift],
         ISNULL([Accept Qty],0) as [Accept Qty], 
        ISNULL([Reject Qty],0) as [Reject Qty],
        ISNULL([Test],0) as [Test],
        cast(ISNULL([Accept Qty],0) as int)+
        cast(ISNULL([Reject Qty],0) as int)+
        cast(ISNULL([Test],0) as int)
        as [Total Completion],
        [last_update],
        ROW_NUMBER() OVER(ORDER BY last_update ASC) AS line
	   --,[sequence]
	   from (
			--select p.id as last_process_id,p.revn as last_process_revn, p.last_update, d.process_matrix_id, d.label, d.value			
	    select  d.label, d.value,p.last_update			
			from [BsWebService].[dbo].bpm_process_detail d with (nolock)
				inner join [BsWebService].[dbo].bpm_process_matrix m with (nolock) on d.process_matrix_id=m.id 
				inner join [BsWebService].[dbo].bpm_process p with (nolock) on m.process_id=p.id and m.process_revn=p.revn and p.status='close' 
				inner join [BsWebService].[dbo].bpm_process_template t with (nolock) on t.id=@route_sheet_tmpl_id
				-- inner join bpm_process_template t on t.id='IT-20220811153141'
				and  d.process_matrix_id in(
					select process_matrix_id 
					from [BsWebService].[dbo].bpm_process_detail with (nolock)
					where label='Work Order No' and value=@order_no
					-- where label='Work Order No' and value='210000162553'
				) 
				and  d.process_matrix_id in(
					select process_matrix_id 
					from [BsWebService].[dbo].bpm_process_detail with (nolock)
					where label='Station' and value=@station
					-- where label='Station' and value='1 - Parafilm and stent crimping WI-10784'
				) 
				and d.process_matrix_id in(
					select process_matrix_id 
					from [BsWebService].[dbo].bpm_process_detail with (nolock)
					where label='sequence' and value!='null' --value>0, removed due to error Conversion failed when converting the nvarchar value 'null' to data type int.
				) 

			) detailResult  
		PIVOT ( 
			MAX(value)  
			for label in (
				[Shift],
				[Accept Qty], 
				[Reject Qty],
				[Test],
				[sequence]
			) 
		) as route_sheet_table 
		order by [sequence]

	END
    ELSE IF (@mode='Amend existing' AND @process_id != 'N/A')
        BEGIN
        select 
                [From Shift],
				[Accept Qty], 
				[Reject Qty],
				[Test],
				[Total Completion],
				[Last Update On],
                [line]
        
         from (
			select tc.label,tc.value,tc.row_index+1 as [line]			
			from [BsWebService].[dbo].bpm_process_table_cell tc with (nolock)
				inner join [BsWebService].[dbo].bpm_process_detail d with (nolock) on tc.parent_process_detail_id=d.id
				inner join [BsWebService].[dbo].bpm_process_matrix m with (nolock) on d.process_matrix_id=m.id 
				inner join [BsWebService].[dbo].bpm_process p with (nolock) on m.process_id=p.id and m.process_revn=p.revn and p.status='close' 
				and p.id=@process_id
				-- and p.id='prd-rs-01-20220821112251'
				and d.label='Completed Qty of Current Station'
			) detailResult  
		PIVOT ( 
			MAX(value)  
			for label in (
				[From Shift],
				[Accept Qty], 
				[Reject Qty],
				[Test],
				[Total Completion],
				[Last Update On]
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
