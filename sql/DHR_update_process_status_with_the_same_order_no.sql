USE [BpmTemplate]
GO
/****** Object:  StoredProcedure [dbo].[DHR_update_process_status_with_the_same_order_no]    Script Date: 31/8/2023 5:13:08 pm ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Ya Dong Zhu
-- Create date: 17 June 2022
-- Description:	this is SP for update the status of DHR Process (Mtl issurance,Route Sheet, confirmation etc) that has the same order no with the passed process
-- if mode = include, then update the status for the process with the process_id and process_revn
-- if mode = exclude, then update the status for the process with that is NOT the process_id and process_revn but the same template of it.
-- usage example: exec [dbo].[BPM_Material_issuing_Update_Status] 'exclude','cancel','<matrix_id>'
-- usage example 2: exec [dbo].[BPM_Material_issuing_Update_Status] 'include','in progress','<matrix_id>'
-- =============================================
ALTER PROCEDURE [dbo].[DHR_update_process_status_with_the_same_order_no]
	-- Add the parameters for the stored procedure here
    @mode varchar(10), -- include or exclude
    @change_to_status varchar(20), -- close, cancel or in progress
    @matrix_id varchar(40) -- this is the matrix id of automator
AS
BEGIN
    DECLARE @process_id varchar(40);
    DECLARE @process_revn TINYINT;
    select @process_id=process_id,@process_revn=process_revn 
    from [BsWebService].dbo.bpm_process_matrix
    where id=@matrix_id

    BEGIN TRANSACTION
    if (@mode = 'include')
        BEGIN
            UPDATE d
            set d.value=@change_to_status
            from [BsWebService].dbo.bpm_process_detail d 
            inner join [BsWebService].dbo.bpm_process_matrix m on d.process_matrix_id=m.id
            inner join [BsWebService].dbo.bpm_process p on m.process_id=@process_id and m.process_revn=@process_revn
            where d.label='status'
        END
    ELSE
        BEGIN
            declare @orderNo varchar(20); -- the orderNo the process related
            declare @tmpl_id varchar(40); -- the template id for the process

            select @tmpl_id=p.process_template_id,@orderNo=d.value
            from [BsWebService].dbo.bpm_process_detail d 
                inner join [BsWebService].dbo.bpm_process_matrix m on d.process_matrix_id=m.id
                inner join [BsWebService].dbo.bpm_process p on m.process_id=p.id and m.process_revn=p.revn 
            where p.id=@process_id and p.revn=@process_revn and d.label='order No'

			update [BsWebService].dbo.bpm_process 
                set [status]=@change_to_status
               from [BsWebService].dbo.bpm_process p
			inner join [BsWebService].dbo.bpm_process_matrix m on p.id=m.process_id and p.revn=m.process_revn
			where m.id in (
                    select process_matrix_id 
                    from [BsWebService].dbo.bpm_process_detail d 
                    inner join [BsWebService].dbo.bpm_process_matrix m on d.process_matrix_id=m.id
                    inner join [BsWebService].dbo.bpm_process p on m.process_id=p.id and 
                                        m.process_revn=p.revn and 
                                        p.process_template_id=@tmpl_id 
                                            and p.id != @process_id
                    where label='Order No' and value=@orderNo
                )  
        END
	COMMIT;
END
