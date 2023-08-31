USE [BpmTemplate]
GO
/****** Object:  StoredProcedure [dbo].[DHR_attachment_by_order_no]    Script Date: 31/8/2023 5:01:17 pm ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Ya Dong Zhu
-- Create date: 9 Sept 2022
-- Description:	find all the attachment for a order No associated with a route sheet 
-- this SP is used in Prod Confirm and QC Confirm templates

-- =============================================
ALTER PROCEDURE [dbo].[DHR_attachment_by_order_no]
	-- Add the parameters for the stored procedure here
    @route_sheet_tmpl_family varchar(100), 
    @order_no varchar(40),
	@attachment_list_name varchar(200) --Route Sheet Attachment List, Previous Production Confirmation Attachment List
AS
BEGIN
	select
   process_id,
   [sequence],
   [station],
   [Upload By],
   [Upload On],
   [Attachment Name],
   [Attachment URL] 
from (select m.process_id,
         (select d.[value] 
            from[BsWebService].[dbo].bpm_process_detail d with (nolock)
               inner join [BsWebService].[dbo].bpm_process_matrix m with (nolock)
                  on d.process_matrix_id = m.id and d.label = 'sequence' and m.process_id = p.id
         ) as [sequence],
		(select top 1 d.[value] 
			  from [BsWebService].[dbo].bpm_process_detail d with (nolock) 
				 inner join [BsWebService].[dbo].bpm_process_matrix m with (nolock) 
					on d.process_matrix_id = m.id 
					and d.label = 'Station Hidden' 
					and m.process_id = p.id
		   ) as [station],
         d.id as table_id,
         tc.label,
         tc.value 
      from  [BsWebService].[dbo].bpm_process_table_cell tc with (nolock)
         inner join [BsWebService].[dbo].bpm_process_detail d with (nolock)
            on tc.parent_process_detail_id = d.id 
         inner join [BsWebService].[dbo].bpm_process_matrix m with (nolock)
            on d.process_matrix_id = m.id 
            --and d.label like '%Attachment List%' 
			and d.label like '%'+@attachment_list_name+'%' 
            --and d.label != 'Material Issuance Attachment List' 
            and m.process_id in 
            ( select pp.id 
               from [BsWebService].[dbo].bpm_process pp with (nolock) 
                  inner join [BsWebService].[dbo].bpm_process_matrix mm with (nolock) 
                     on mm.process_id = pp.id 
                     and mm.process_revn = pp.revn 
                     and pp.status = 'close' 
                  inner join
                     [BsWebService].[dbo].bpm_process_detail dd with (nolock) 
                     on dd.process_matrix_id = mm.id 
                     and dd.label = 'Order No' 
                     --and dd.value = '210000162552' 
					 and dd.value = @order_no 
                  inner join
                     [BsWebService].[dbo].bpm_process_template t with (nolock) 
                     on t.id = pp.process_template_id 							
					 and t.name like @route_sheet_tmpl_family+'%'
                     --and t.name like 'DHR Production Route Sheet%' 
            )
         inner join [BsWebService].[dbo].bpm_process p with (nolock) 
            on m.process_id = p.id 
            and m.process_revn = p.revn 
         inner join [BsWebService].[dbo].[func_get_all_employees](DEFAULT) e 
            on e.user_id = m.user_id 
   )  tableResult 
   PIVOT ( MAX(value) for [label] in 
   (
      [Attachment Name],
      [Attachment URL],
      [Upload By],
      [Upload On] 
   )
) as pivot_table 
UNION ALL
select p.id as process_id,
   (select top 1 d.[value] 
      from [BsWebService].[dbo].bpm_process_detail d with (nolock) 
         inner join [BsWebService].[dbo].bpm_process_matrix m with (nolock) 
            on d.process_matrix_id = m.id 
            and d.label = 'sequence' 
            and m.process_id = p.id
   ) as [sequence],
   (select top 1 d.[value] 
      from [BsWebService].[dbo].bpm_process_detail d with (nolock) 
         inner join [BsWebService].[dbo].bpm_process_matrix m with (nolock) 
            on d.process_matrix_id = m.id 
            and d.label = 'Station Hidden' 
            and m.process_id = p.id
   ) as [station],
   e.first_name + ' ' + e.last_name + ' (' + e.user_id + ')' as [Upload By],
   ( select top 1 action_on 
      from [BsWebService].[dbo].bpm_process_matrix m with (nolock) 
      where process_id = p.id 
         and process_revn = p.revn 
         and (m.action = 'action-complete' or m.action='submit')
   ) as [Upload On],
   a.file_path as [Attachment Name],
   '/download/' + a.process_matrix_id + '/' + a.file_path as [Attachment URL] 
from [BsWebService].[dbo].bpm_process_attachement a with (nolock) 
   inner join [BsWebService].[dbo].bpm_process_matrix m with (nolock) 
      on a.process_matrix_id = m.id 
and m.process_id in 
            ( select pp.id 
               from [BsWebService].[dbo].bpm_process pp with (nolock) 
                  inner join [BsWebService].[dbo].bpm_process_matrix mm with (nolock) 
                     on mm.process_id = pp.id 
                     and mm.process_revn = pp.revn 
                     and pp.status = 'close' 
                  inner join
                     [BsWebService].[dbo].bpm_process_detail dd with (nolock) 
                     on dd.process_matrix_id = mm.id 
                     and dd.label = 'Order No' 
                     --and dd.value = '210000162552' 
					 and dd.value = @order_no 
                  inner join
                     [BsWebService].[dbo].bpm_process_template t with (nolock) 
                     on t.id = pp.process_template_id 							
					 and t.name like @route_sheet_tmpl_family+'%'
                     --and t.name like 'DHR Production Route Sheet%' 
            )
   inner join [BsWebService].[dbo].bpm_process p with (nolock) 
      on m.process_id = p.id 
      and m.process_revn = p.revn 
     
   inner join [BsWebService].[dbo].[func_get_all_employees](DEFAULT) e 
      on e.user_id = p.initiate_by 
order by [station]
END
