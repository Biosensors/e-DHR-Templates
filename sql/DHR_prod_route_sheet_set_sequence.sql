USE [BpmTemplate]
GO
/****** Object:  StoredProcedure [dbo].[DHR_prod_route_sheet_set_sequence]    Script Date: 31/8/2023 5:11:49 pm ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Ya Dong Zhu
-- Create date: 19 August 2022
-- Description:	this is SP for retrieving sequence of route sheet

-- =============================================
ALTER PROCEDURE [dbo].[DHR_prod_route_sheet_set_sequence]
	-- Add the parameters for the stored procedure here
	@mode varchar(20), -- either "Create new" or "Amend existing"
    @order_no varchar(40), -- production order no -- for "Create New"
    @process_id varchar(40), -- existing process ID -- for "Amend existing"
    @route_sheet_tmpl_id varchar(40) -- associate with route sheet template name
AS
BEGIN
    BEGIN TRY
    DECLARE @sequence TINYINT =1;
    IF  (@mode='Create new' and @order_no!='N/A' and @order_no is not NULL) 
	BEGIN --find related process_id based on order no and station (latest one)
        select count (distinct p.id) +1 as [sequence]
            from 
			[BsWebService].[dbo].bpm_process p with (nolock) inner join [BsWebService].[dbo].bpm_process_matrix m with (nolock)
			on m.process_id=p.id 
              and m.process_revn=p.revn 
              and m.type='initiator'
              and p.status='close' 
              and p.process_template_id=@route_sheet_tmpl_id
            --  and p.process_template_id='IT-20220811153141' 
			inner join [BsWebService].[dbo].bpm_process_detail d with (nolock)
            on d.process_matrix_id=m.id and
			    d.process_matrix_id in(
                    select process_matrix_id 
                    from [BsWebService].[dbo].bpm_process_detail with (nolock)
                    where label='Order No' and value=@order_no
                    --  where label='Order No' and value='210000162552'
                ) 

	END
    ELSE IF (@mode='Amend existing' AND @process_id != 'N/A')
        BEGIN
            if (NOT EXISTS(
                select 1 from [BsWebService].[dbo].bpm_process with (nolock) where id=@process_id and status='close' and process_template_id=@route_sheet_tmpl_id
            ))
                RAISERROR ('Process %s not found in template "%s" ',16,1,@process_id,@route_sheet_tmpl_id );   
            else 
                select d.value as [sequence]
                from [BsWebService].[dbo].bpm_process p with (nolock)
                inner join [BsWebService].[dbo].bpm_process_matrix m with (nolock)
                    on m.process_id=p.id 
                    and m.process_revn=p.revn 
                    and m.type='initiator'
                    and p.status='close' 
                    and p.id=@process_id 
                    --and p.id='prd-rs-01-20220816105307' 
                inner join [BsWebService].[dbo].bpm_process_detail d with (nolock)
                    on d.process_matrix_id=m.id and d.label='route sheet sequence'                        
        END
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
