USE [BpmTemplate]
GO
/****** Object:  StoredProcedure [dbo].[DHR_get_remaining_qty_from_current_station]    Script Date: 31/8/2023 5:07:06 pm ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Ya Dong Zhu
-- Create date: 03 May 2023
-- Description:	this SP is used in Production Route Sheet template, and will find :
-- 1. remaining qty for current station

-- =============================================
ALTER PROCEDURE [dbo].[DHR_get_remaining_qty_from_current_station]
	-- Add the parameters for the stored procedure here
    @last_accept_qty varchar(10),
    @order_no varchar(40), -- production order no -- for "Create New"
    @current_station nvarchar(200) -- current station
AS
BEGIN
    Declare @station nvarchar(100);
    Declare @remainning_qty int;
select	@station=[Station],
		@remainning_qty=((CAST(@last_accept_qty as int)
		- CASE WHEN SUM(cast([Accept Qty] as int)) IS NOT NULL THEN SUM(cast([Accept Qty] as int)) ELSE 0 END
		- CASE WHEN SUM(cast([Reject Qty] as int)) IS NOT NULL THEN SUM(cast([Reject Qty] as int)) ELSE 0 END
		- CASE WHEN SUM(cast([Test] as int)) IS NOT NULL THEN SUM(cast([Test] as int)) ELSE 0 END))
		from (
			select 
			p.id as last_process_id,p.revn as last_process_revn, 
			d.label, d.value			
			from [BsWebService].[dbo].bpm_process_detail d 
				inner join [BsWebService].[dbo].bpm_process_matrix m on d.process_matrix_id=m.id 
				inner join [BsWebService].[dbo].bpm_process p on m.process_id=p.id and m.process_revn=p.revn and p.status='close'
				inner join [BsWebService].[dbo].bpm_process_template t on t.id=p.process_template_id
				and t.name like 'DHR Production Route Sheet%'
				and d.process_matrix_id in(
					select process_matrix_id 
					from [BsWebService].[dbo].bpm_process_detail 
					where label='Work Order No' and value=@order_no
					--where label='Work Order No' and value='210000196576'
				) 
			) detailResult  
		PIVOT ( 
			MAX(value)  
			for label in (
				[Station],
				[Accept Qty],
				[Reject Qty],
				[Test]
			) 
		)  pivot_table 
		where [Station]=@current_station
		--where [Station]='2 - Parafilm And Stent Crimping (WI-10784)'
		--where [Station]='1 - Stent Deployment Process (WI-10784)'
		group by [Station]

		if (@@ROWCOUNT=0) 
			select @current_station as [Station], CAST(@last_accept_qty as int) as [Remaining Qty]
		else 
			select @station as [Station],@remainning_qty as [Remaining Qty]
END
