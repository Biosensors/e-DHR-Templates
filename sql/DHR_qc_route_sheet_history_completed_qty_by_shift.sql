USE [BpmTemplate]
GO
/****** Object:  StoredProcedure [dbo].[DHR_qc_route_sheet_history_completed_qty_by_shift]    Script Date: 31/8/2023 5:12:07 pm ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Ya Dong Zhu
-- Create date: 11 SEPT 2022
-- Description:	this is SP for retrieving the completed qty of previous shifts
--return columns:
    --     [From Shift],
    --     [Reject Qty], 
    --     [Total Test Qty],
    --     [Destructive Test Qty],
	--		[Pass/Fail],
    --     [Remark / NCIR / Test],
    --     [last_update],
-- =============================================
ALTER PROCEDURE [dbo].[DHR_qc_route_sheet_history_completed_qty_by_shift]
	-- Add the parameters for the stored procedure here
	@mode varchar(20), -- either "Create new" or "Amend existing"
    @order_no varchar(40), -- production order no -- for "Create New"
    @process_id varchar(40), -- existing process ID -- for "Amend existing"
    @route_sheet_tmpl_id varchar(40) -- associate with route sheet template name
AS
BEGIN
	BEGIN TRY
    IF  (@mode='Create new' and @order_no!='N/A') --create new and order no is provided
	BEGIN --find related process_id based on squence (latest one)
        select  
        [Shift] as [From Shift],
        [Reject Qty], 
        [Total Test Qty],
        [Destructive Test Qty],
        [Remark / NCIR / Test],
        [last_update],
        ROW_NUMBER() OVER(ORDER BY last_update ASC) AS line,
		'/#/my-open-processes/view-detail/'+pid+'/'+cast(prevn as varchar) as process_url,
		pid as process_id
	   --,[sequence]
	   from (
			--select p.id as last_process_id,p.revn as last_process_revn, p.last_update, d.process_matrix_id, d.label, d.value			
	    select p.id as pid,p.revn as prevn, d.label, d.value,p.last_update			
			from [BsWebService].[dbo].bpm_process_detail d with (nolock)
				inner join [BsWebService].[dbo].bpm_process_matrix m with (nolock) on d.process_matrix_id=m.id 
				inner join [BsWebService].[dbo].bpm_process p with (nolock) on m.process_id=p.id and m.process_revn=p.revn and p.status='close' 
				and p.process_template_id=@route_sheet_tmpl_id
				-- and p.process_template_id='IT-20220824102552'
				and  d.process_matrix_id in(
					select process_matrix_id 
					from [BsWebService].[dbo].bpm_process_detail with (nolock)
					where label='Order No' and value=@order_no
					--  where label='Order No' and value='210000162552'
				) 
				and d.process_matrix_id in(
					select process_matrix_id 
					from [BsWebService].[dbo].bpm_process_detail with (nolock)
					where label='route sheet sequence' and value>0
				) 

			) detailResult  
		PIVOT ( 
			MAX(value)  
			for label in (
				[Shift],
				[Reject Qty], 
				[Total Test Qty],
				[Destructive Test Qty],
				[Remark / NCIR / Test],
				[sequence]
			) 
		) as route_sheet_table 
		order by [sequence]

	END
    ELSE IF (@mode='Amend existing' AND @process_id != 'N/A')
        BEGIN
        select 
                [From Shift],
				[Reject Qty], 
				[Total Test Qty],
				[Destructive Test Qty],
				[Remark / NCIR / Test],
				[Update On] as last_update,
				[Process URL],
				ROW_NUMBER() OVER(ORDER BY [Update On] ASC) AS line
        
         from (
			select tc.label,tc.value,tc.row_index+1 as [line]			
			from [BsWebService].[dbo].bpm_process_table_cell tc with (nolock)
				inner join [BsWebService].[dbo].bpm_process_detail d with (nolock) on tc.parent_process_detail_id=d.id
				inner join [BsWebService].[dbo].bpm_process_matrix m with (nolock) on d.process_matrix_id=m.id 
				inner join [BsWebService].[dbo].bpm_process p with (nolock) on m.process_id=p.id and m.process_revn=p.revn and p.status='close' 
				and p.id=@process_id
				--  and p.id='qc-rs-01-20220911181952'
				and d.label='Completed Qty in Previous Shifts'
			) detailResult  
		PIVOT ( 
			MAX(value)  
			for label in (
				[From Shift],
				[Reject Qty], 
				[Total Test Qty],
				[Destructive Test Qty],
				[Remark / NCIR / Test],
				[Update On],
				[Process URL]

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
