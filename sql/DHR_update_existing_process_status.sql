USE [BpmTemplate]
GO
/****** Object:  StoredProcedure [dbo].[DHR_update_existing_process_status]    Script Date: 31/8/2023 5:12:44 pm ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Ya Dong Zhu
-- Create date: 22 aug 2022
-- Description:	this is SP for update the status of existing route sheet Process
-- usage example: exec [dbo].[DHR_update_existing_process_status] '<automator_matrix_id>'
-- =============================================
ALTER PROCEDURE [dbo].[DHR_update_existing_process_status]
	-- Add the parameters for the stored procedure here
    @matrix_id varchar(40) -- this is the matrix id of automator
AS
BEGIN
    BEGIN TRANSACTION
        BEGIN
            DECLARE @existing_pid varchar(40);
            select @existing_pid=d.value 
            from  [BsWebService].[dbo].bpm_process_detail d with (nolock)
            inner join [BsWebService].[dbo].bpm_process_matrix m with (nolock)
            on d.process_matrix_id=m.id and d.label='Target Process ID' and m.type='initiator'
            inner join [BsWebService].[dbo].bpm_process p with (nolock)
            on m.process_id=p.id and m.process_revn=p.revn 
            and p.status='pending_action' and p.id in (
                select process_id 
                from [BsWebService].[dbo].bpm_process_matrix with (nolock)
                where id=@matrix_id  
            )
            if (@existing_pid IS NOT NULL)
                UPDATE  [BsWebService].[dbo].bpm_process
                SET [status]='cancel',
                    [cancel_on]=GetUTCDate()
                WHERE [id]=@existing_pid and [status]='close'
            else 
                print ('existing_pid with status=close not found')    
        END
	COMMIT;
END
