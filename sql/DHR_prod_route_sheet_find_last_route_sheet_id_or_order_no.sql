USE [BpmTemplate]
GO
/****** Object:  StoredProcedure [dbo].[DHR_prod_route_sheet_find_last_route_sheet_id_or_order_no]    Script Date: 31/8/2023 5:07:40 pm ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Ya Dong Zhu
-- Create date: 14 August 2022
-- Description:	this SP will find :
-- 1. in Create New Mode: last process_id (with station available)
-- 2. in Amend Existing mode: order_no

-- =============================================
ALTER PROCEDURE [dbo].[DHR_prod_route_sheet_find_last_route_sheet_id_or_order_no]
	-- Add the parameters for the stored procedure here
	@mode varchar(20), -- either "Create new" or "Amend existing"
    @order_no varchar(40), -- production order no -- for "Create New"
    @station nvarchar(200)=NULL, -- station -- for "Create New"
    @process_id varchar(40), -- existing process ID -- for "Amend existing"
    @route_sheet_tmpl_id varchar(40) -- associate with route sheet template name
AS
BEGIN
	BEGIN TRY
	IF (@mode='Create new' and @station='N/A' and @order_no!='N/A')
        SELECT @order_no as [Order No]  -- if create new, but @station is not provide, only return order_no
    ELSE IF (@mode='Create new' and @station is NULL and @order_no!='N/A') -- QC Route sheet
       BEGIN
            select  top 1  @process_id= p.id from [BsWebService].[dbo].bpm_process p with (nolock)
                inner join [BsWebService].[dbo].bpm_process_matrix m with (nolock) on m.type='initiator' 
                    and m.process_id=p.id and m.process_revn=p.revn and p.status='close'
					and p.process_template_id=@route_sheet_tmpl_id
                inner join [BsWebService].[dbo].bpm_process_detail d with (nolock) on d.process_matrix_id=m.id 
                    and  d.process_matrix_id in(
                        select process_matrix_id 
                        from [BsWebService].[dbo].bpm_process_detail with (nolock) 
                        where label='Order No' and value=@order_no
                        -- where label='Order No' and value='210000162552'
                    ) 
                    and d.label='route sheet sequence'
                order by d.value desc

       END
	ELSE IF  (@mode='Create new' and @order_no!='N/A') --station is not null
	BEGIN --find related process_id based on squence (latest one)
        select  top 1  @process_id= p.id from [BsWebService].[dbo].bpm_process p with (nolock)
                inner join [BsWebService].[dbo].bpm_process_matrix m with (nolock) on m.type='initiator' 
                    and m.process_id=p.id and m.process_revn=p.revn and p.status='close'
					and p.process_template_id=@route_sheet_tmpl_id
                inner join [BsWebService].[dbo].bpm_process_detail d with (nolock) on d.process_matrix_id=m.id 
                    and  d.process_matrix_id in(
                        select process_matrix_id 
                        from [BsWebService].[dbo].bpm_process_detail  with (nolock)
                        where label='Order No' and value=@order_no
                        -- where label='Order No' and value='210000162552'
                    ) 
                    and 
                    d.process_matrix_id in(
                        select process_matrix_id 
                        from [BsWebService].[dbo].bpm_process_detail with (nolock)
                        where label='Choose Station' and value=@station
                        -- where label='Choose Station' and value='1 - Stent deployment Process(Applicable for BioFreedom Cocr stent only) WI-10784'
                    ) 
                    and d.label='route sheet sequence'
                order by d.value desc

	END
    ELSE IF (@mode='Amend existing' AND @process_id != 'N/A')
        BEGIN
            if (NOT EXISTS(
                select 1 from [BsWebService].[dbo].bpm_process with (nolock) where id=@process_id and status='close' and process_template_id=@route_sheet_tmpl_id
            ))
                RAISERROR ('Process %s not found in template "%s" ',16,1,@process_id,@route_sheet_tmpl_id );               
        END

   IF (@process_id is NOT NULL AND @process_id != 'N/A')     
        select * from (
            select @process_id as process_id,d.label, d.value			
            from [BsWebService].[dbo].bpm_process_detail d with (nolock)
                inner join [BsWebService].[dbo].bpm_process_matrix m with (nolock) on d.process_matrix_id=m.id and m.type='initiator'
                inner join [BsWebService].[dbo].bpm_process p with (nolock) on m.process_id=p.id and m.process_revn=p.revn 
                and p.id= @process_id and p.status='close'
            ) detailResult  
        PIVOT ( 
            MAX(value)  
            for label in (
                [Order No]
            ) 
        )  pivot_table 
    ELSE IF (@process_id is NULL or @process_id='N/A')
            SELECT @order_no as [Order No]

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
